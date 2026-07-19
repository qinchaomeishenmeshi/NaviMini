import XCTest
@testable import NaviMini

final class CoverArtPresentationTests: XCTestCase {
  func testShouldNotApplyWhenTaskCancelled() {
    XCTAssertFalse(
      CoverArtPresentation.shouldApplyLoadedImage(
        isTaskCancelled: true,
        requestedCoverArtID: "art-1",
        currentCoverArtID: "art-1"
      )
    )
  }

  func testShouldNotApplyWhenCurrentCoverChanged() {
    XCTAssertFalse(
      CoverArtPresentation.shouldApplyLoadedImage(
        isTaskCancelled: false,
        requestedCoverArtID: "art-1",
        currentCoverArtID: "art-2"
      )
    )
  }

  func testShouldApplyWhenStillCurrent() {
    XCTAssertTrue(
      CoverArtPresentation.shouldApplyLoadedImage(
        isTaskCancelled: false,
        requestedCoverArtID: "art-1",
        currentCoverArtID: "art-1"
      )
    )
  }
}
