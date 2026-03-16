import Foundation

final class AudioCache: NSObject, URLSessionDownloadDelegate {
  static let shared = AudioCache()

  private let ioQueue = DispatchQueue(label: "audio.cache.io")
  private var inProgress = Set<String>()
  private let supportedExtensions: Set<String> = ["mp3", "m4a", "aac"]
  private let whitelistExtensions: Set<String> = ["mp3", "m4a", "aac", "flac", "ogg"]

  func healthCheck() {
    let entries = CacheIndex.shared.allEntries()
    guard let root = CacheIndex.shared.cacheRootURL() else { return }
    var scanned = 0
    var removed = 0

    for (key, entry) in entries where entry.type == "audio" {
      scanned += 1
      let url = root.appendingPathComponent(entry.relativePath)
      let exists = FileManager.default.fileExists(atPath: url.path)
      let ext = URL(fileURLWithPath: entry.relativePath).pathExtension.lowercased()
      if !exists || entry.size <= 0 || !supportedExtensions.contains(ext) {
        try? FileManager.default.removeItem(at: url)
        CacheIndex.shared.remove(key: key)
        removed += 1
      }
    }

    MetricsLogger.shared.log("cache_health audio scanned=\(scanned) removed=\(removed)")
  }

  private var downloadQueue: [(songId: String, url: URL)] = []
  private var pendingSet = Set<String>()
  private var activeSet = Set<String>()
  private var taskToSongId: [Int: String] = [:]
  private var resumeDataBySongId: [String: Data] = [:]
  private let maxConcurrentDownloads = 2

  private lazy var backgroundSession: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: "NaviMini.audio.background")
    config.sessionSendsLaunchEvents = true
    config.isDiscretionary = false
    config.allowsCellularAccess = true
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  private var cacheRoot: URL? {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
      .appendingPathComponent("Cache", isDirectory: true)
  }

  private var audioDir: URL? {
    cacheRoot?.appendingPathComponent("audio", isDirectory: true)
  }

  private override init() {
    super.init()
    prepareDirs()
  }

  func localURL(for songId: String) -> URL? {
    let key = cacheKey(for: songId)
    guard let entry = CacheIndex.shared.entry(for: key) else {
      return nil
    }
    guard entry.size > 0 else {
      print("[AudioCache] invalid entry size=0 songId=\(songId)")
      return nil
    }
    let ext = URL(fileURLWithPath: entry.relativePath).pathExtension.lowercased()
    guard supportedExtensions.contains(ext) else {
      print("[AudioCache] unsupported extension=\(ext) songId=\(songId), invalidating")
      invalidate(songId: songId)
      return nil
    }
    guard let root = cacheRoot else { return nil }
    let url = root.appendingPathComponent(entry.relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
      print("[AudioCache] missing file songId=\(songId) path=\(entry.relativePath)")
      return nil
    }
    CacheIndex.shared.recordAccess(key: key)
    print("[AudioCache] hit songId=\(songId)")
    return url
  }

  func invalidate(songId: String) {
    let key = cacheKey(for: songId)
    guard let entry = CacheIndex.shared.entry(for: key) else { return }
    guard let root = cacheRoot else { return }
    let url = root.appendingPathComponent(entry.relativePath)
    try? FileManager.default.removeItem(at: url)
    CacheIndex.shared.remove(key: key)
    print("[AudioCache] invalidated songId=\(songId)")
  }

  func cacheStream(url: URL, songId: String) {
    ioQueue.async {
      if self.inProgress.contains(songId) { return }
      self.inProgress.insert(songId)

      let request = URLRequest(url: url)
      let task = URLSession.shared.downloadTask(with: request) { tempURL, response, error in
        defer {
          self.ioQueue.async { self.inProgress.remove(songId) }
        }

        if let error {
          print("[AudioCache] error songId=\(songId) \(error.localizedDescription)")
          return
        }

        let mime = response?.mimeType ?? ""

        guard mime.hasPrefix("audio/") else {
          print("[AudioCache] skip cache (non-audio) songId=\(songId) mime=\(mime)")
          return
        }

        guard let tempURL, let destURL = self.fileURL(for: songId, response: response) else {
          print("[AudioCache] error songId=\(songId) missing temp or dest")
          return
        }

        do {
          try? FileManager.default.removeItem(at: destURL)
          try FileManager.default.moveItem(at: tempURL, to: destURL)
          let size = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? NSNumber)?.intValue ?? 0
          CacheIndex.shared.touch(
            key: self.cacheKey(for: songId),
            type: "audio",
            relativePath: self.relativePath(for: songId, response: response),
            size: size
          )
          print("[AudioCache] saved songId=\(songId) size=\(size)")
        } catch {
          print("[AudioCache] error songId=\(songId) save failed")
        }
      }
      task.resume()
    }
  }

  func enqueueDownload(songId: String, url: URL) {
    ioQueue.async {
      if self.pendingSet.contains(songId) || self.activeSet.contains(songId) { return }
      if self.localURL(for: songId) != nil { return }
      self.downloadQueue.append((songId: songId, url: url))
      self.pendingSet.insert(songId)
      self.startNextIfNeeded()
    }
  }

  private func startNextIfNeeded() {
    while activeSet.count < maxConcurrentDownloads, !downloadQueue.isEmpty {
      let next = downloadQueue.removeFirst()
      pendingSet.remove(next.songId)
      activeSet.insert(next.songId)

      let task: URLSessionDownloadTask
      if let resume = resumeDataBySongId.removeValue(forKey: next.songId) {
        task = backgroundSession.downloadTask(withResumeData: resume)
      } else {
        task = backgroundSession.downloadTask(with: next.url)
      }
      task.taskDescription = next.songId
      taskToSongId[task.taskIdentifier] = next.songId
      task.resume()
    }
  }

  // MARK: - URLSessionDownloadDelegate
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    let songId = downloadTask.taskDescription ?? taskToSongId[downloadTask.taskIdentifier]
    guard let songId else { return }

    let mime = downloadTask.response?.mimeType ?? ""
    guard mime.hasPrefix("audio/") else {
      try? FileManager.default.removeItem(at: location)
      return
    }

    guard let destURL = fileURL(for: songId, response: downloadTask.response) else { return }

    do {
      try? FileManager.default.removeItem(at: destURL)
      try FileManager.default.moveItem(at: location, to: destURL)
      let size = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? NSNumber)?.intValue ?? 0
      CacheIndex.shared.touch(
        key: cacheKey(for: songId),
        type: "audio",
        relativePath: relativePath(for: songId, response: downloadTask.response),
        size: size
      )
    } catch {
      // ignore
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    let songId = task.taskDescription ?? taskToSongId[task.taskIdentifier]
    if let songId {
      if let error = error as NSError?,
         let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
        resumeDataBySongId[songId] = resumeData
      }
      activeSet.remove(songId)
      taskToSongId.removeValue(forKey: task.taskIdentifier)
      startNextIfNeeded()
    }
  }

  private func cacheKey(for id: String) -> String {
    "audio:\(id)"
  }

  private func inferredExtension(from response: URLResponse?) -> String {
    if let name = response?.suggestedFilename {
      let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
      if whitelistExtensions.contains(ext) {
        return ext
      }
    }
    if let mime = response?.mimeType?.lowercased() {
      switch mime {
      case "audio/mpeg": return "mp3"
      case "audio/mp4": return "m4a"
      case "audio/x-m4a": return "m4a"
      case "audio/aac": return "aac"
      case "audio/flac": return "flac"
      case "audio/ogg": return "ogg"
      default: break
      }
    }
    return "dat"
  }

  private func relativePath(for id: String, response: URLResponse?) -> String {
    let ext = inferredExtension(from: response)
    return "audio/\(id).\(ext)"
  }

  private func fileURL(for id: String, response: URLResponse?) -> URL? {
    guard let dir = audioDir else { return nil }
    let ext = inferredExtension(from: response)
    return dir.appendingPathComponent(id).appendingPathExtension(ext)
  }

  private func prepareDirs() {
    guard let root = cacheRoot, let audio = audioDir else { return }
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(at: audio, withIntermediateDirectories: true)
  }
}
