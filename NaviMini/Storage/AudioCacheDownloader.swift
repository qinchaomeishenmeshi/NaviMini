import Foundation

protocol AudioCacheDownloading: AnyObject {
  func ensureCached(remoteURL: URL, cacheKey: AudioCacheKey)
}

protocol AudioCacheNetworking {
  func download(from url: URL) async throws -> (URL, URLResponse)
}

extension URLSession: AudioCacheNetworking {
  func download(from url: URL) async throws -> (URL, URLResponse) {
    try await download(from: url, delegate: nil)
  }
}

final class AudioCacheDownloader: AudioCacheDownloading {
  private let store: AudioCacheStore
  private let networkClient: AudioCacheNetworking
  private let inFlightKeys = AudioCacheInFlightRegistry()

  init(
    store: AudioCacheStore,
    networkClient: AudioCacheNetworking = URLSession.shared
  ) {
    self.store = store
    self.networkClient = networkClient
  }

  func ensureCached(remoteURL: URL, cacheKey: AudioCacheKey) {
    Task(priority: .utility) { [store, networkClient, inFlightKeys] in
      guard await inFlightKeys.begin(cacheKey) else { return }
      defer { Task { await inFlightKeys.finish(cacheKey) } }

      if store.cachedFileURLIfComplete(for: cacheKey) != nil {
        return
      }

      MetricsLogger.shared.log("audio_cache_download_started song=\(cacheKey.songId) format=\(cacheKey.formatKey)")

      do {
        let (temporaryURL, response) = try await networkClient.download(from: remoteURL)
        guard let httpResponse = response as? HTTPURLResponse else {
          throw NSError(
            domain: "AudioCacheDownloader",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "non-http audio cache response"]
          )
        }
        guard (200...299).contains(httpResponse.statusCode) else {
          throw NSError(
            domain: "AudioCacheDownloader",
            code: httpResponse.statusCode,
            userInfo: [NSLocalizedDescriptionKey: "audio cache download failed with status \(httpResponse.statusCode)"]
          )
        }
        if let mimeType = response.mimeType?.lowercased(),
           Self.disallowedMimeTypes.contains(mimeType) {
          throw NSError(
            domain: "AudioCacheDownloader",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "unexpected audio cache mime type \(mimeType)"]
          )
        }
        if Self.shouldInspectResponseBody(mimeType: response.mimeType),
           try Self.looksLikeStructuredText(at: temporaryURL) {
          throw NSError(
            domain: "AudioCacheDownloader",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "unexpected structured text response body"]
          )
        }
        let expectedContentLength = response.expectedContentLength > 0 ? response.expectedContentLength : nil
        _ = try store.persistDownloadedFile(
          from: temporaryURL,
          for: cacheKey,
          expectedContentLength: expectedContentLength
        )
        MetricsLogger.shared.log("audio_cache_download_finished song=\(cacheKey.songId) format=\(cacheKey.formatKey)")
      } catch {
        MetricsLogger.shared.log(
          "audio_cache_download_failed song=\(cacheKey.songId) format=\(cacheKey.formatKey) error=\(error.localizedDescription)"
        )
      }
    }
  }
}

extension AudioCacheDownloader {
  private static let disallowedMimeTypes: Set<String> = [
    "application/json",
    "application/xml",
    "text/html",
    "text/plain",
    "text/xml"
  ]

  private static func shouldInspectResponseBody(mimeType: String?) -> Bool {
    guard let mimeType = mimeType?.lowercased() else { return true }
    return mimeType == "application/octet-stream"
  }

  private static func looksLikeStructuredText(at url: URL) throws -> Bool {
    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
    let prefix = data.prefix(256)
    guard !prefix.isEmpty else { return false }

    let trimmedPrefix = prefix.drop { byte in
      byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }
    guard let first = trimmedPrefix.first else { return false }

    if first == UInt8(ascii: "{") || first == UInt8(ascii: "[") || first == UInt8(ascii: "<") {
      return true
    }

    return false
  }
}

private actor AudioCacheInFlightRegistry {
  private var keys: Set<AudioCacheKey> = []

  func begin(_ key: AudioCacheKey) -> Bool {
    let inserted = keys.insert(key).inserted
    return inserted
  }

  func finish(_ key: AudioCacheKey) {
    keys.remove(key)
  }
}
