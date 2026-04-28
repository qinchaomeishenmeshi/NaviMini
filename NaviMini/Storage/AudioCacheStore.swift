import Foundation

struct AudioCacheKey: Hashable {
  let songId: String
  let formatKey: String
  let originalFileExtension: String?

  var fileName: String {
    "\(Self.sanitized(songId))_\(Self.sanitized(formatKey)).\(pathExtension)"
  }

  private var pathExtension: String {
    if let originalFileExtension = sanitizedFileExtension(originalFileExtension) {
      return originalFileExtension
    }

    let prefix = formatKey.split(separator: "_").first.map(String.init)?.lowercased()
    switch prefix {
    case "mp3":
      return "mp3"
    case "flac":
      return "flac"
    case "raw":
      return "raw"
    default:
      return "audio"
    }
  }

  init(songId: String, formatKey: String, originalFileExtension: String? = nil) {
    self.songId = songId
    self.formatKey = formatKey
    self.originalFileExtension = originalFileExtension
  }

  private static func sanitized(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
    return String(scalars)
  }

  private func sanitizedFileExtension(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let normalized = trimmed.hasPrefix(".") ? String(trimmed.dropFirst()) : trimmed
    let sanitized = Self.sanitized(normalized).lowercased()
    return sanitized.isEmpty ? nil : sanitized
  }
}

final class AudioCacheStore {
  private let fileManager: FileManager
  private let maxCacheSizeBytes: Int64
  let cacheDirectoryURL: URL

  init(
    cacheDirectoryURL: URL? = nil,
    maxCacheSizeBytes: Int64 = 8 * 1024 * 1024 * 1024,
    fileManager: FileManager = .default
  ) {
    self.fileManager = fileManager
    self.maxCacheSizeBytes = maxCacheSizeBytes
    self.cacheDirectoryURL = cacheDirectoryURL ?? Self.defaultCacheDirectoryURL(fileManager: fileManager)
    try? fileManager.createDirectory(at: self.cacheDirectoryURL, withIntermediateDirectories: true)
  }

  func fileURL(for key: AudioCacheKey) -> URL {
    try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
    return cacheDirectoryURL.appendingPathComponent(key.fileName, isDirectory: false)
  }

  func cachedFileURLIfComplete(for key: AudioCacheKey) -> URL? {
    let url = fileURL(for: key)
    guard fileManager.fileExists(atPath: url.path) else { return nil }

    do {
      let attributes = try fileManager.attributesOfItem(atPath: url.path)
      let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
      guard fileSize > 0 else {
        try? fileManager.removeItem(at: url)
        return nil
      }
      return url
    } catch {
      try? fileManager.removeItem(at: url)
      return nil
    }
  }

  func persistDownloadedFile(
    from temporaryURL: URL,
    for key: AudioCacheKey,
    expectedContentLength: Int64? = nil
  ) throws -> URL {
    let fileSize = try actualFileSize(at: temporaryURL)
    guard fileSize > 0 else {
      throw NSError(domain: "AudioCacheStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "empty audio cache file"])
    }
    if let expectedContentLength, expectedContentLength > 0, expectedContentLength != fileSize {
      throw NSError(domain: "AudioCacheStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "audio cache file size mismatch"])
    }

    let destinationURL = fileURL(for: key)
    if fileManager.fileExists(atPath: destinationURL.path) {
      try? fileManager.removeItem(at: destinationURL)
    }
    try fileManager.moveItem(at: temporaryURL, to: destinationURL)
    pruneIfNeeded(keeping: destinationURL)
    return destinationURL
  }

  func removeCache(for key: AudioCacheKey) {
    try? fileManager.removeItem(at: fileURL(for: key))
  }

  private func actualFileSize(at url: URL) throws -> Int64 {
    let attributes = try fileManager.attributesOfItem(atPath: url.path)
    return (attributes[.size] as? NSNumber)?.int64Value ?? 0
  }

  private func pruneIfNeeded(keeping protectedURL: URL) {
    guard maxCacheSizeBytes > 0 else { return }
    guard var entries = cacheEntries() else { return }

    var totalSize = entries.reduce(Int64(0)) { $0 + $1.size }
    guard totalSize > maxCacheSizeBytes else { return }

    entries.sort { lhs, rhs in
      if lhs.url == protectedURL { return false }
      if rhs.url == protectedURL { return true }
      return lhs.modificationDate < rhs.modificationDate
    }

    for entry in entries where totalSize > maxCacheSizeBytes {
      guard entry.url != protectedURL else { continue }
      try? fileManager.removeItem(at: entry.url)
      totalSize -= entry.size
    }
  }

  private func cacheEntries() -> [CacheEntry]? {
    guard let urls = try? fileManager.contentsOfDirectory(
      at: cacheDirectoryURL,
      includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
      options: [.skipsHiddenFiles]
    ) else {
      return nil
    }

    return urls.compactMap { url in
      guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
            let fileSize = values.fileSize else {
        return nil
      }
      return CacheEntry(
        url: url,
        size: Int64(fileSize),
        modificationDate: values.contentModificationDate ?? .distantPast
      )
    }
  }

  private static func defaultCacheDirectoryURL(fileManager: FileManager) -> URL {
    let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? fileManager.temporaryDirectory
    return baseURL.appendingPathComponent("AudioCache", isDirectory: true)
  }
}

private struct CacheEntry {
  let url: URL
  let size: Int64
  let modificationDate: Date
}
