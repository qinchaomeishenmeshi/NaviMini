import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
  @Published private(set) var songs: [Song] = []
  @Published var isRefreshing: Bool = false
  @Published var isLoadingMore: Bool = false
  @Published var hasMore: Bool = true
  @Published var errorText: String?

  private var loadedCount: Int = 0
  private var totalCount: Int = 0
  private var hasDiscoveredTotalCount: Bool = false
  private let pageSize: Int = 50

  init() {
    songs = []
    loadedCount = 0
    totalCount = 0
    hasMore = false
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
    } catch {
      errorText = Self.userFacingMessage(for: error)
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
      errorText = Self.userFacingMessage(for: error)
    }

    isLoadingMore = false
  }

  nonisolated static func userFacingMessage(for error: Error) -> String {
    if let urlError = error as? URLError {
      switch urlError.code {
      case .notConnectedToInternet, .networkConnectionLost:
        return "网络不可用，请检查连接后重试。"
      case .timedOut:
        return "连接超时，请稍后重试。"
      case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
        return "无法连接服务器，请确认地址是否正确。"
      default:
        break
      }
    }

    let raw = error.localizedDescription
    let lowered = raw.lowercased()
    if lowered.contains("unauthorized")
      || lowered.contains("401")
      || lowered.contains("403")
      || raw.contains("认证")
      || raw.contains("密码") {
      return "认证失败，请检查用户名或密码。"
    }

    return "无法加载歌曲，请稍后重试。"
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
