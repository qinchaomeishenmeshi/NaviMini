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

  func testNormalizedPlaybackTimeClampsToDuration() {
    XCTAssertEqual(
      PlaybackQueueLogic.normalizedPlaybackTime(rawCurrentSeconds: 270, duration: 259),
      259,
      accuracy: 0.001
    )
    XCTAssertEqual(
      PlaybackQueueLogic.normalizedPlaybackTime(rawCurrentSeconds: -2, duration: 259),
      0,
      accuracy: 0.001
    )
  }

  func testNormalizedPlaybackTimeFallsBackToRawWhenDurationMissing() {
    XCTAssertEqual(
      PlaybackQueueLogic.normalizedPlaybackTime(rawCurrentSeconds: 88.6, duration: nil),
      88.6,
      accuracy: 0.001
    )
    XCTAssertEqual(
      PlaybackQueueLogic.normalizedPlaybackTime(rawCurrentSeconds: .nan, duration: 100),
      0,
      accuracy: 0.001
    )
  }

  func testProjectedPlaybackTimeAdvancesOnlyWhenPlaying() {
    XCTAssertEqual(
      PlaybackQueueLogic.projectedPlaybackTime(
        baseSeconds: 100,
        elapsedSinceAnchor: 0.4,
        isPlaying: true,
        duration: 120
      ),
      100.4,
      accuracy: 0.001
    )

    XCTAssertEqual(
      PlaybackQueueLogic.projectedPlaybackTime(
        baseSeconds: 100,
        elapsedSinceAnchor: 2,
        isPlaying: false,
        duration: 120
      ),
      100,
      accuracy: 0.001
    )
  }

  func testProjectedPlaybackTimeIsClampedByDuration() {
    XCTAssertEqual(
      PlaybackQueueLogic.projectedPlaybackTime(
        baseSeconds: 119.9,
        elapsedSinceAnchor: 2,
        isPlaying: true,
        duration: 120
      ),
      120,
      accuracy: 0.001
    )
  }
}
