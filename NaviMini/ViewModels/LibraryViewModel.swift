import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
  @Published private(set) var songs: [Song] = []
  @Published var isRefreshing: Bool = false
  @Published var isLoadingMore: Bool = false
  @Published var hasMore: Bool = true
  @Published var errorText: String?

  private let cache = SongsCache()
  private var loadedCount: Int = 0
  private var totalCount: Int = 0
  private var hasDiscoveredTotalCount: Bool = false
  private let pageSize: Int = 50

  init() {
    songs = cache.load()
    loadedCount = songs.count
    totalCount = songs.count
    hasMore = loadedCount > 0
  }

  func refresh(client: SubsonicClient) async {
    isRefreshing = true
    errorText = nil
    defer { isRefreshing = false }

    do {
      let totalSongCount = try await discoverTotalSongCount(client: client)
      let initialOffset = Self.initialRefreshOffset(totalSongCount: totalSongCount, pageSize: pageSize)
      let list = try await client.searchAllSongs(songCount: pageSize, songOffset: initialOffset)
      songs = list
      totalCount = totalSongCount
      hasDiscoveredTotalCount = true
      loadedCount = initialOffset + list.count
      hasMore = loadedCount < totalCount
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
      if hasDiscoveredTotalCount {
        hasMore = loadedCount < totalCount
      } else {
        hasMore = !newSongs.isEmpty
        if newSongs.isEmpty {
          totalCount = loadedCount
          hasDiscoveredTotalCount = true
        }
      }
    } catch {
      errorText = error.localizedDescription
    }

    isLoadingMore = false
  }

  private func discoverTotalSongCount(client: SubsonicClient) async throws -> Int {
    if try await client.searchAllSongs(songCount: 1, songOffset: 0).isEmpty {
      return 0
    }

    var lowerBound = 0
    var upperBound = 1

    while true {
      let page = try await client.searchAllSongs(songCount: 1, songOffset: upperBound)
      if page.isEmpty {
        break
      }
      lowerBound = upperBound
      upperBound *= 2
    }

    while lowerBound + 1 < upperBound {
      let mid = (lowerBound + upperBound) / 2
      let page = try await client.searchAllSongs(songCount: 1, songOffset: mid)
      if page.isEmpty {
        upperBound = mid
      } else {
        lowerBound = mid
      }
    }

    return lowerBound + 1
  }

  nonisolated static func initialRefreshOffset(totalSongCount: Int, pageSize: Int) -> Int {
    guard totalSongCount > pageSize else { return 0 }
    return 0
  }
}
