import Foundation
import XCTest
@testable import NaviMini

final class AudioCacheStoreTests: XCTestCase {
  private var tempDirectoryURL: URL!
  private var store: AudioCacheStore!

  override func setUpWithError() throws {
    tempDirectoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    store = AudioCacheStore(cacheDirectoryURL: tempDirectoryURL)
  }

  override func tearDownWithError() throws {
    if let tempDirectoryURL {
      try? FileManager.default.removeItem(at: tempDirectoryURL)
    }
  }

  func testCacheKeyIncludesSongIdAndFormat() {
    let mp3Key = AudioCacheKey(songId: "song-123", formatKey: SubsonicClient.StreamFormat.mp3(maxBitRate: 192).cacheKey)
    let rawKey = AudioCacheKey(songId: "song-123", formatKey: SubsonicClient.StreamFormat.raw.cacheKey)

    XCTAssertNotEqual(mp3Key.fileName, rawKey.fileName)
    XCTAssertTrue(mp3Key.fileName.contains("song-123"))
    XCTAssertTrue(mp3Key.fileName.contains("mp3_192"))
  }

  func testCacheKeyUsesPlayableFileExtensionForFormat() {
    let mp3Key = AudioCacheKey(
      songId: "song-123",
      formatKey: SubsonicClient.StreamFormat.mp3(maxBitRate: 192).cacheKey
    )
    let rawKey = AudioCacheKey(
      songId: "song-123",
      formatKey: SubsonicClient.StreamFormat.raw.cacheKey,
      originalFileExtension: "flac"
    )

    XCTAssertEqual((mp3Key.fileName as NSString).pathExtension, "mp3")
    XCTAssertEqual((rawKey.fileName as NSString).pathExtension, "flac")
  }

  func testCompleteCacheExistsWhenFileIsReadableAndNonEmpty() throws {
    let key = AudioCacheKey(songId: "song-123", formatKey: "mp3_192")
    let fileURL = store.fileURL(for: key)
    try Data("cached".utf8).write(to: fileURL)

    XCTAssertEqual(store.cachedFileURLIfComplete(for: key), fileURL)
  }

  func testBrokenCacheIsRemoved() throws {
    let key = AudioCacheKey(songId: "song-123", formatKey: "mp3_192")
    let fileURL = store.fileURL(for: key)
    try Data().write(to: fileURL)

    XCTAssertNil(store.cachedFileURLIfComplete(for: key))
    XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
  }

  func testDefaultMaxCacheSizeIsEightGigabytes() {
    let child = Mirror(reflecting: store!).children.first { $0.label == "maxCacheSizeBytes" }
    let maxCacheSizeBytes = child?.value as? Int64

    XCTAssertEqual(maxCacheSizeBytes, 8 * 1024 * 1024 * 1024)
  }

  func testPersistDownloadedFilePrunesOldestCacheWhenSizeLimitExceeded() throws {
    store = AudioCacheStore(cacheDirectoryURL: tempDirectoryURL, maxCacheSizeBytes: 10)

    let oldKey = AudioCacheKey(songId: "old-song", formatKey: "mp3_192")
    let oldURL = store.fileURL(for: oldKey)
    try Data("12345".utf8).write(to: oldURL)
    let oldDate = Date(timeIntervalSince1970: 100)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldURL.path)

    let newKey = AudioCacheKey(songId: "new-song", formatKey: "mp3_192")
    let tempDownloadURL = tempDirectoryURL.appendingPathComponent("download.tmp")
    try Data("678901".utf8).write(to: tempDownloadURL)

    let persistedURL = try store.persistDownloadedFile(from: tempDownloadURL, for: newKey)

    XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
    XCTAssertEqual(store.cachedFileURLIfComplete(for: newKey), persistedURL)
  }
}
