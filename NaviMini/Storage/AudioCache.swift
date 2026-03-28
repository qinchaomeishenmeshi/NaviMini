import Foundation

final class AudioCache: NSObject, URLSessionDownloadDelegate {
  static let shared = AudioCache()

  private let ioQueue = DispatchQueue(label: "audio.cache.io")
  private var inProgress = Set<String>()
  private var downloadQueue: [(songId: String, url: URL)] = []
  private var pendingSet = Set<String>()
  private var activeSet = Set<String>()
  private var taskToSongId: [Int: String] = [:]
  private var resumeDataBySongId: [String: Data] = [:]
  private let maxConcurrentDownloads = 2
  private let supportedExtensions: Set<String> = ["mp3", "m4a", "aac", "flac", "ogg"]

  private lazy var backgroundSession: URLSession = {
    let config = Self.makeDownloadSessionConfiguration()
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

  static func makeDownloadSessionConfiguration(identifier: String = "NaviMini.audio.background") -> URLSessionConfiguration {
    let config = URLSessionConfiguration.background(withIdentifier: identifier)
    config.sessionSendsLaunchEvents = true
    config.isDiscretionary = false
    config.allowsCellularAccess = true
    return config
  }

  static func acceptsAudioResponse(_ response: URLResponse?) -> Bool {
    guard let mime = response?.mimeType?.lowercased() else { return false }
    return mime.hasPrefix("audio/")
  }

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

  func localURL(for songId: String) -> URL? {
    let key = cacheKey(for: songId)
    guard let entry = CacheIndex.shared.entry(for: key), entry.size > 0 else { return nil }
    let ext = URL(fileURLWithPath: entry.relativePath).pathExtension.lowercased()
    guard supportedExtensions.contains(ext) else {
      invalidate(songId: songId)
      return nil
    }
    guard let root = cacheRoot else { return nil }
    let url = root.appendingPathComponent(entry.relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    CacheIndex.shared.recordAccess(key: key)
    return url
  }

  func invalidate(songId: String) {
    let key = cacheKey(for: songId)
    guard let entry = CacheIndex.shared.entry(for: key) else { return }
    guard let root = cacheRoot else { return }
    let url = root.appendingPathComponent(entry.relativePath)
    try? FileManager.default.removeItem(at: url)
    CacheIndex.shared.remove(key: key)
  }

  func cacheSong(url: URL, songId: String) {
    ioQueue.async {
      if self.inProgress.contains(songId) { return }
      if self.localURL(for: songId) != nil { return }
      self.inProgress.insert(songId)
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
    ioQueue.async {
      let songId = downloadTask.taskDescription ?? self.taskToSongId[downloadTask.taskIdentifier]
      guard let songId else { return }

      guard AudioCache.acceptsAudioResponse(downloadTask.response) else {
        try? FileManager.default.removeItem(at: location)
        return
      }

      guard let destURL = self.fileURL(for: songId, response: downloadTask.response) else { return }

      do {
        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.moveItem(at: location, to: destURL)
        let size = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0 else {
          try? FileManager.default.removeItem(at: destURL)
          return
        }

        CacheIndex.shared.touch(
          key: self.cacheKey(for: songId),
          type: "audio",
          relativePath: self.relativePath(for: songId, response: downloadTask.response),
          size: size
        )
      } catch {
        try? FileManager.default.removeItem(at: location)
      }
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    ioQueue.async {
      let songId = task.taskDescription ?? self.taskToSongId[task.taskIdentifier]
      if let songId {
        if let error = error as NSError?,
           let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
          self.resumeDataBySongId[songId] = resumeData
        }
        self.activeSet.remove(songId)
        self.inProgress.remove(songId)
        self.taskToSongId.removeValue(forKey: task.taskIdentifier)
        self.startNextIfNeeded()
      }
    }
  }

  private func cacheKey(for id: String) -> String {
    "audio:\(id)"
  }

  private func inferredExtension(from response: URLResponse?) -> String {
    if let name = response?.suggestedFilename {
      let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
      if supportedExtensions.contains(ext) {
        return ext
      }
    }
    if let mime = response?.mimeType?.lowercased() {
      switch mime {
      case "audio/mpeg": return "mp3"
      case "audio/mp4", "audio/x-m4a": return "m4a"
      case "audio/aac": return "aac"
      case "audio/flac": return "flac"
      case "audio/ogg": return "ogg"
      default: break
      }
    }
    return "mp3"
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
