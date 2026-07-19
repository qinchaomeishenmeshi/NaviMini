import XCTest
@testable import NaviMini

@MainActor
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

  func testLoadMoreIsIgnoredWhileRefreshing() async {
    let catalog = (0..<60).map(Self.makeSong)
    let client = MockSongLibraryClient(songs: catalog)
    let vm = LibraryViewModel()

    await vm.refresh(client: client)
    XCTAssertEqual(vm.songs.count, 50)
    XCTAssertTrue(vm.hasMore)

    vm.isRefreshing = true
    await vm.loadMore(client: client)

    XCTAssertEqual(vm.songs.count, 50)
    XCTAssertFalse(vm.isLoadingMore)
  }

  func testInFlightLoadMoreDoesNotAppendAfterRefreshStarts() async {
    let catalog = (0..<80).map(Self.makeSong)
    let client = MockSongLibraryClient(songs: catalog)
    let vm = LibraryViewModel()

    await vm.refresh(client: client)
    XCTAssertEqual(vm.songs.map(\.id), catalog.prefix(50).map(\.id))

    await client.setDelayNanoseconds(150_000_000)
    let loadMoreTask = Task { await vm.loadMore(client: client) }

    try? await Task.sleep(nanoseconds: 30_000_000)
    await client.setDelayNanoseconds(0)
    await vm.refresh(client: client)
    await loadMoreTask.value

    XCTAssertEqual(vm.songs.map(\.id), catalog.prefix(50).map(\.id))
    XCTAssertFalse(vm.songs.map(\.id).contains("song-50"))
    XCTAssertFalse(vm.isLoadingMore)
  }

  private static func makeSong(index: Int) -> Song {
    Song(
      id: "song-\(index)",
      title: "Song \(index)",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil
    )
  }
}

private actor MockSongLibraryClient: SongLibraryFetching {
  private let songs: [Song]
  private var delayNanoseconds: UInt64 = 0

  init(songs: [Song]) {
    self.songs = songs
  }

  func setDelayNanoseconds(_ value: UInt64) {
    delayNanoseconds = value
  }

  func searchAllSongs(songCount: Int, songOffset: Int) async throws -> [Song] {
    if delayNanoseconds > 0 {
      try await Task.sleep(nanoseconds: delayNanoseconds)
    }
    guard songOffset < songs.count else { return [] }
    let end = min(songOffset + songCount, songs.count)
    return Array(songs[songOffset..<end])
  }
}
