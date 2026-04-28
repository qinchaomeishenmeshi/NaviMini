import AVFoundation
import XCTest
@testable import NaviMini

@MainActor
final class PlaybackQueueItemFactoryTests: XCTestCase {
  private let client = SubsonicClient(
    baseURL: URL(string: "https://example.com/rest")!,
    username: "user",
    password: "pass"
  )
  private var tempDirectoryURL: URL!
  private var cacheStore: AudioCacheStore!
  private var downloader: AudioCacheDownloaderSpy!
  private var factory: PlaybackQueueItemFactory!

  override func setUpWithError() throws {
    tempDirectoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    cacheStore = AudioCacheStore(cacheDirectoryURL: tempDirectoryURL)
    downloader = AudioCacheDownloaderSpy()
    factory = PlaybackQueueItemFactory(cacheStore: cacheStore, cacheDownloader: downloader)
  }

  override func tearDownWithError() throws {
    if let tempDirectoryURL {
      try? FileManager.default.removeItem(at: tempDirectoryURL)
    }
  }

  func testMakeItemUsesRemoteStreamUrl() {
    let songId = UUID().uuidString
    let song = Song(
      id: songId,
      title: "Remote",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil
    )

    let queueItem = factory.makeItem(for: song, client: client)

    XCTAssertEqual(
      (queueItem.item.asset as? AVURLAsset)?.url,
      client.streamURL(songId: songId, format: .mp3(maxBitRate: 192))
    )
    XCTAssertEqual(queueItem.source, .remote)
    XCTAssertEqual(downloader.requests.count, 1)
  }

  func testMakeItemUsesRawStreamForFlacSource() {
    let songId = UUID().uuidString
    let song = Song(
      id: songId,
      title: "Lossless",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil,
      sourceFormat: "flac"
    )

    let queueItem = factory.makeItem(for: song, client: client)

    XCTAssertEqual(
      (queueItem.item.asset as? AVURLAsset)?.url,
      client.streamURL(songId: songId, format: .raw)
    )
    XCTAssertEqual(queueItem.source, .remote)
    XCTAssertEqual(downloader.requests.count, 1)
  }

  func testMakeItemUsesCachedFileWhenCompleteCacheExists() throws {
    let songId = UUID().uuidString
    let song = Song(
      id: songId,
      title: "Cached",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil
    )
    let key = AudioCacheKey(songId: songId, formatKey: SubsonicClient.StreamFormat.mp3(maxBitRate: 192).cacheKey)
    let fileURL = cacheStore.fileURL(for: key)
    try Data("cached".utf8).write(to: fileURL)

    let queueItem = factory.makeItem(for: song, client: client)

    XCTAssertEqual((queueItem.item.asset as? AVURLAsset)?.url, fileURL)
    XCTAssertEqual(queueItem.source, .localCache)
    XCTAssertTrue(downloader.requests.isEmpty)
  }

  func testMakeItemDeletesBrokenCacheAndFallsBackToRemote() throws {
    let songId = UUID().uuidString
    let song = Song(
      id: songId,
      title: "Broken",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil
    )
    let key = AudioCacheKey(songId: songId, formatKey: SubsonicClient.StreamFormat.mp3(maxBitRate: 192).cacheKey)
    let fileURL = cacheStore.fileURL(for: key)
    try Data().write(to: fileURL)

    let queueItem = factory.makeItem(for: song, client: client)

    XCTAssertEqual(
      (queueItem.item.asset as? AVURLAsset)?.url,
      client.streamURL(songId: songId, format: .mp3(maxBitRate: 192))
    )
    XCTAssertEqual(queueItem.source, .remote)
    XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    XCTAssertEqual(downloader.requests.count, 1)
  }
}

private final class AudioCacheDownloaderSpy: AudioCacheDownloading {
  struct Request: Equatable {
    let remoteURL: URL
    let cacheKey: AudioCacheKey
  }

  private(set) var requests: [Request] = []

  func ensureCached(remoteURL: URL, cacheKey: AudioCacheKey) {
    requests.append(Request(remoteURL: remoteURL, cacheKey: cacheKey))
  }
}
