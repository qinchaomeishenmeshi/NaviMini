import AVFoundation
import XCTest
@testable import NaviMini

@MainActor
final class PlaybackQueueItemFactoryTests: XCTestCase {
  private let factory = PlaybackQueueItemFactory()
  private let client = SubsonicClient(
    baseURL: URL(string: "https://example.com/rest")!,
    username: "user",
    password: "pass"
  )

  func testMakeItemUsesLocalCacheWhenAvailable() async throws {
    let songId = UUID().uuidString
    let song = Song(
      id: songId,
      title: "Cached",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil
    )
    let localURL = try await createCachedAudioFile(songId: songId)

    let queueItem = factory.makeItem(for: song, client: client, forceRemote: false)

    XCTAssertTrue(queueItem.isLocal)
    XCTAssertEqual((queueItem.item.asset as? AVURLAsset)?.url, localURL)
  }

  func testMakeItemIgnoresLocalCacheWhenForceRemote() async throws {
    let songId = UUID().uuidString
    let song = Song(
      id: songId,
      title: "Forced Remote",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil
    )
    let _ = try await createCachedAudioFile(songId: songId)

    let queueItem = factory.makeItem(for: song, client: client, forceRemote: true)

    XCTAssertFalse(queueItem.isLocal)
    XCTAssertEqual((queueItem.item.asset as? AVURLAsset)?.url, client.streamURL(songId: songId))
  }

  private func createCachedAudioFile(songId: String) async throws -> URL {
    guard let root = CacheIndex.shared.cacheRootURL() else {
      throw NSError(domain: "PlaybackQueueItemFactoryTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "missing cache root"])
    }

    let audioDir = root.appendingPathComponent("audio", isDirectory: true)
    try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

    let url = audioDir.appendingPathComponent(songId).appendingPathExtension("mp3")
    let data = Data([0x01, 0x02, 0x03])
    try data.write(to: url, options: [.atomic])

    CacheIndex.shared.touch(
      key: "audio:\(songId)",
      type: "audio",
      relativePath: "audio/\(songId).mp3",
      size: data.count
    )

    _ = try await waitForLocalURL(songId: songId)
    return url
  }

  private func waitForLocalURL(songId: String, timeoutSeconds: Double = 2) async throws -> URL {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
      if let url = AudioCache.shared.localURL(for: songId) {
        return url
      }
      try await Task.sleep(nanoseconds: 20_000_000)
    }

    throw NSError(
      domain: "PlaybackQueueItemFactoryTests",
      code: 2,
      userInfo: [NSLocalizedDescriptionKey: "timed out waiting for local cache entry"]
    )
  }
}
