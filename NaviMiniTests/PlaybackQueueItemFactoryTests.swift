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

    XCTAssertEqual((queueItem.item.asset as? AVURLAsset)?.url, client.streamURL(songId: songId))
  }
}
