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

  func testUserFacingMessageMapsCommonNetworkFailures() {
    let offline = LibraryViewModel.userFacingMessage(
      for: URLError(.notConnectedToInternet)
    )
    XCTAssertEqual(offline, "网络不可用，请检查连接后重试。")

    let timeout = LibraryViewModel.userFacingMessage(for: URLError(.timedOut))
    XCTAssertEqual(timeout, "连接超时，请稍后重试。")
  }

  func testUserFacingMessageDoesNotAppendSystemRawText() {
    struct DummyError: LocalizedError {
      var errorDescription: String? { "The operation couldn’t be completed. (NSURLErrorDomain error -999.)" }
    }

    let message = LibraryViewModel.userFacingMessage(for: DummyError())
    XCTAssertEqual(message, "无法加载歌曲，请稍后重试。")
    XCTAssertFalse(message.contains("NSURLErrorDomain"))
  }
}
