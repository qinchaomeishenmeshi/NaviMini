import Foundation
import XCTest
@testable import NaviMini

final class SubsonicClientTests: XCTestCase {
  private let client = SubsonicClient(
    baseURL: URL(string: "https://example.com/rest")!,
    username: "user",
    password: "pass"
  )

  func testStreamURLUsesRawFormatWithoutBitrate() {
    let url = client.streamURL(songId: "song-1", format: .raw)
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let queryItems = components?.queryItems ?? []

    XCTAssertEqual(queryItems.first(where: { $0.name == "format" })?.value, "raw")
    XCTAssertNil(queryItems.first(where: { $0.name == "maxBitRate" }))
  }

  func testStreamURLUsesMp3BitrateWhenRequested() {
    let url = client.streamURL(songId: "song-1", format: .mp3(maxBitRate: 128))
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let queryItems = components?.queryItems ?? []

    XCTAssertEqual(queryItems.first(where: { $0.name == "format" })?.value, "mp3")
    XCTAssertEqual(queryItems.first(where: { $0.name == "maxBitRate" })?.value, "128")
  }
}
