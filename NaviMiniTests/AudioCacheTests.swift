import XCTest
@testable import NaviMini

final class AudioCacheTests: XCTestCase {
  func testAcceptsAudioResponseWithAudioMimeType() {
    let response = URLResponse(
      url: URL(string: "https://example.com/track.mp3")!,
      mimeType: "audio/mpeg",
      expectedContentLength: 1024,
      textEncodingName: nil
    )

    XCTAssertTrue(AudioCache.acceptsAudioResponse(response))
  }

  func testRejectsHtmlResponseEvenWhenFilenameLooksAudioLike() {
    let response = URLResponse(
      url: URL(string: "https://example.com/track.mp3")!,
      mimeType: "text/html",
      expectedContentLength: 1024,
      textEncodingName: nil
    )

    XCTAssertFalse(AudioCache.acceptsAudioResponse(response))
  }

  func testBackgroundDownloadSessionUsesLaunchEvents() {
    let config = AudioCache.makeDownloadSessionConfiguration(identifier: "test.audio.cache.background")

    XCTAssertEqual(config.identifier, "test.audio.cache.background")
    XCTAssertTrue(config.sessionSendsLaunchEvents)
    XCTAssertFalse(config.isDiscretionary)
    XCTAssertTrue(config.allowsCellularAccess)
  }
}
