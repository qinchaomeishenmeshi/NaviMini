import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
  @Published private(set) var songs: [Song] = []
  @Published var isRefreshing: Bool = false
  @Published var isLoadingMore: Bool = false
  @Published var hasMore: Bool = true
  @Published var errorText: String?

  private let cache: SongsCache
  private var loadedCount: Int = 0
  private let pageSize: Int = 50

  init(cache: SongsCache) {
    self.cache = cache
    self.songs = cache.load()
    self.loadedCount = songs.count
    self.hasMore = loadedCount > 0
  }

  func refresh(client: SubsonicClient) async {
    isRefreshing = true
    errorText = nil
    defer { isRefreshing = false }

    do {
      // 初始只加载第一页
      let list = try await client.searchAllSongs(songCount: pageSize, songOffset: 0)
      songs = list
      loadedCount = list.count
      hasMore = list.count == pageSize
      cache.save(list)
    } catch {
      errorText = error.localizedDescription
    }
  }

  func loadMore(client: SubsonicClient) async {
    guard !isLoadingMore && hasMore else { return }
    isLoadingMore = true

    do {
      let newSongs = try await client.searchAllSongs(
        songCount: pageSize,
        songOffset: loadedCount
      )
      songs.append(contentsOf: newSongs)
      loadedCount += newSongs.count
      hasMore = newSongs.count == pageSize
    } catch {
      errorText = error.localizedDescription
    }

    isLoadingMore = false
  }
}
