import XCTest
@testable import NaviMini

final class LibraryViewModelTests: XCTestCase {
  func testInitialRefreshOffsetAlwaysStartsAtFirstPage() {
    XCTAssertEqual(
      LibraryViewModel.initialRefreshOffset(totalSongCount: 10, pageSize: 50),
      0
    )
    XCTAssertEqual(
      LibraryViewModel.initialRefreshOffset(totalSongCount: 500, pageSize: 50),
      0
    )
  }
}
