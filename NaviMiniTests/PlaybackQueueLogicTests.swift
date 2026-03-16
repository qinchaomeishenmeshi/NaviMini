import XCTest
@testable import NaviMini

final class PlaybackQueueLogicTests: XCTestCase {
  func testNextIndexStopsAtEndOfQueue() {
    XCTAssertEqual(PlaybackQueueLogic.nextIndex(currentIndex: 0, count: 3), 1)
    XCTAssertEqual(PlaybackQueueLogic.nextIndex(currentIndex: 1, count: 3), 2)
    XCTAssertNil(PlaybackQueueLogic.nextIndex(currentIndex: 2, count: 3))
  }

  func testResolvedPlaybackDurationPrefersPlayerItemDuration() {
    let duration = PlaybackQueueLogic.resolvedPlaybackDuration(
      metadataDuration: 180,
      itemDurationSeconds: 201.4
    )
    XCTAssertNotNil(duration)
    XCTAssertEqual(duration!, 201.4, accuracy: 0.001)
  }

  func testResolvedPlaybackDurationFallsBackToMetadataDuration() {
    let duration = PlaybackQueueLogic.resolvedPlaybackDuration(
      metadataDuration: 180,
      itemDurationSeconds: nil
    )
    XCTAssertNotNil(duration)
    XCTAssertEqual(duration!, 180, accuracy: 0.001)
  }

  func testResolvedPlaybackDurationRejectsInvalidItemDuration() {
    let fallbackDuration = PlaybackQueueLogic.resolvedPlaybackDuration(
      metadataDuration: 180,
      itemDurationSeconds: Double.nan
    )
    XCTAssertNotNil(fallbackDuration)
    XCTAssertEqual(fallbackDuration!, 180, accuracy: 0.001)
    XCTAssertNil(
      PlaybackQueueLogic.resolvedPlaybackDuration(
        metadataDuration: nil,
        itemDurationSeconds: Double.infinity
      )
    )
  }
}
