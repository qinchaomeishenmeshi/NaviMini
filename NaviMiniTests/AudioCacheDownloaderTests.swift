import Foundation
import XCTest
@testable import NaviMini

final class AudioCacheDownloaderTests: XCTestCase {
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

  func testDownloaderStartsSingleRequestPerCacheKey() async throws {
    let remoteURL = URL(string: "https://example.com/song.mp3")!
    let key = AudioCacheKey(songId: "song-123", formatKey: "mp3_192")
    let responseFileURL = tempDirectoryURL.appendingPathComponent("source.mp3")
    try Data("cached".utf8).write(to: responseFileURL)

    let networkClient = MockAudioCacheNetworkClient(
      responseURL: responseFileURL,
      response: HTTPURLResponse(
        url: remoteURL,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Length": "6"]
      )!,
      delayNanoseconds: 200_000_000
    )
    let downloader = AudioCacheDownloader(store: store, networkClient: networkClient)

    downloader.ensureCached(remoteURL: remoteURL, cacheKey: key)
    downloader.ensureCached(remoteURL: remoteURL, cacheKey: key)

    try await waitUntilCached(for: key)
    let requestCount = await networkClient.requestCount
    XCTAssertEqual(requestCount, 1)
  }

  func testDownloaderPersistsCompletedDownloadAtomically() async throws {
    let remoteURL = URL(string: "https://example.com/song.mp3")!
    let key = AudioCacheKey(songId: "song-123", formatKey: "mp3_192")
    let responseFileURL = tempDirectoryURL.appendingPathComponent("source.mp3")
    let expectedData = Data("cached".utf8)
    try expectedData.write(to: responseFileURL)

    let networkClient = MockAudioCacheNetworkClient(
      responseURL: responseFileURL,
      response: HTTPURLResponse(
        url: remoteURL,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Length": "6"]
      )!
    )
    let downloader = AudioCacheDownloader(store: store, networkClient: networkClient)

    downloader.ensureCached(remoteURL: remoteURL, cacheKey: key)

    let cachedURL = try await waitUntilCached(for: key)
    XCTAssertEqual(try Data(contentsOf: cachedURL), expectedData)
  }

  func testDownloaderDoesNotPersistNon2xxResponses() async throws {
    let remoteURL = URL(string: "https://example.com/song.mp3")!
    let key = AudioCacheKey(songId: "song-404", formatKey: "mp3_192")
    let responseFileURL = tempDirectoryURL.appendingPathComponent("error.html")
    try Data("<html>not found</html>".utf8).write(to: responseFileURL)

    let networkClient = MockAudioCacheNetworkClient(
      responseURL: responseFileURL,
      response: HTTPURLResponse(
        url: remoteURL,
        statusCode: 404,
        httpVersion: nil,
        headerFields: ["Content-Length": "22"]
      )!
    )
    let downloader = AudioCacheDownloader(store: store, networkClient: networkClient)

    downloader.ensureCached(remoteURL: remoteURL, cacheKey: key)

    try await Task.sleep(nanoseconds: 200_000_000)
    XCTAssertNil(store.cachedFileURLIfComplete(for: key))
  }

  func testDownloaderDoesNotPersistJsonErrorBodyEvenWhenStatusIs200() async throws {
    let remoteURL = URL(string: "https://example.com/song.mp3")!
    let key = AudioCacheKey(songId: "song-json", formatKey: "mp3_192")
    let responseFileURL = tempDirectoryURL.appendingPathComponent("error.json")
    let errorBody = """
    {"subsonic-response":{"status":"failed","error":{"code":70,"message":"data not found"}}}
    """
    try Data(errorBody.utf8).write(to: responseFileURL)

    let networkClient = MockAudioCacheNetworkClient(
      responseURL: responseFileURL,
      response: HTTPURLResponse(
        url: remoteURL,
        statusCode: 200,
        httpVersion: nil,
        headerFields: [
          "Content-Length": String(errorBody.utf8.count),
          "Content-Type": "application/json"
        ]
      )!
    )
    let downloader = AudioCacheDownloader(store: store, networkClient: networkClient)

    downloader.ensureCached(remoteURL: remoteURL, cacheKey: key)

    try await Task.sleep(nanoseconds: 200_000_000)
    XCTAssertNil(store.cachedFileURLIfComplete(for: key))
  }

  func testDownloaderDoesNotPersistJsonErrorBodyWhenMimeTypeIsOctetStream() async throws {
    let remoteURL = URL(string: "https://example.com/song.mp3")!
    let key = AudioCacheKey(songId: "song-octet-json", formatKey: "mp3_192")
    let responseFileURL = tempDirectoryURL.appendingPathComponent("error.bin")
    let errorBody = """
    {"subsonic-response":{"status":"failed","error":{"code":70,"message":"data not found"}}}
    """
    try Data(errorBody.utf8).write(to: responseFileURL)

    let networkClient = MockAudioCacheNetworkClient(
      responseURL: responseFileURL,
      response: HTTPURLResponse(
        url: remoteURL,
        statusCode: 200,
        httpVersion: nil,
        headerFields: [
          "Content-Length": String(errorBody.utf8.count),
          "Content-Type": "application/octet-stream"
        ]
      )!
    )
    let downloader = AudioCacheDownloader(store: store, networkClient: networkClient)

    downloader.ensureCached(remoteURL: remoteURL, cacheKey: key)

    try await Task.sleep(nanoseconds: 200_000_000)
    XCTAssertNil(store.cachedFileURLIfComplete(for: key))
  }

  private func waitUntilCached(for key: AudioCacheKey) async throws -> URL {
    for _ in 0..<50 {
      if let url = store.cachedFileURLIfComplete(for: key) {
        return url
      }
      try await Task.sleep(nanoseconds: 50_000_000)
    }

    XCTFail("expected cache file for \(key.fileName)")
    throw CancellationError()
  }
}

private actor MockAudioCacheNetworkClient: AudioCacheNetworking {
  private(set) var requestCount: Int = 0

  let responseURL: URL
  let response: URLResponse
  let delayNanoseconds: UInt64

  init(responseURL: URL, response: URLResponse, delayNanoseconds: UInt64 = 0) {
    self.responseURL = responseURL
    self.response = response
    self.delayNanoseconds = delayNanoseconds
  }

  func download(from url: URL) async throws -> (URL, URLResponse) {
    requestCount += 1
    if delayNanoseconds > 0 {
      try await Task.sleep(nanoseconds: delayNanoseconds)
    }
    return (responseURL, response)
  }
}
