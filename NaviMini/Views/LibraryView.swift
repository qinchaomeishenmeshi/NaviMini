import SwiftUI

struct LibraryView: View {
  @ObservedObject var session: SessionStore
  @StateObject private var vm: LibraryViewModel

  @ObservedObject var playback: PlaybackController

  @State private var pendingIndex: Int? = nil
  @State private var didAutoRefresh: Bool = false

  init(session: SessionStore, playback: PlaybackController) {
    self.session = session
    self.playback = playback
    _vm = StateObject(wrappedValue: LibraryViewModel(cache: session.cache))
  }

  var body: some View {
    ScrollViewReader { proxy in
      List {
        // 错误区域
        if let error = vm.errorText {
          Section {
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
              Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
            }
          }
        }

        // 歌曲列表
        ForEach(Array(vm.songs.enumerated()), id: \.element.id) { (index, song) in
          let isCurrent = (playback.current?.id == song.id)
          let isPending = (pendingIndex == index) && !isCurrent

          SongRowView(
            song: song,
            isCurrent: isCurrent,
            isPending: isPending,
            onTap: { playSong(at: index) }
          )
          .id(song.id)
          .onAppear {
            if index == vm.songs.count - 1 {
              if !vm.isLoadingMore && vm.hasMore {
                Task {
                  do {
                    let client = try session.makeClient()
                    await vm.loadMore(client: client)
                  } catch {
                    await MainActor.run {
                      vm.errorText = error.localizedDescription
                    }
                  }
                }
              }
            }
          }
        }

        // 加载更多指示器
        if vm.isLoadingMore {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
          .listRowBackground(Color.clear)
        }
      }
      .listStyle(.inset)
      .navigationTitle("歌曲")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: refresh) {
            if vm.isRefreshing {
              ProgressView()
            } else {
              Image(systemName: "arrow.clockwise")
                .symbolVariant(.circle)
            }
          }
          .accessibilityLabel("刷新歌曲列表")
          .disabled(vm.isRefreshing)
        }

        ToolbarItem(placement: .topBarLeading) {
          NavigationLink(destination: PlayerView(session: session, playback: playback)) {
            Label("正在播放", systemImage: "play.circle")
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .font(.subheadline.weight(.semibold))
        }
      }
      .onAppear {
        if !didAutoRefresh {
          didAutoRefresh = true
          refresh()
        }
      }
      .onReceive(playback.$current) { song in
        pendingIndex = nil
        guard let song else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
          proxy.scrollTo(song.id, anchor: .center)
        }
      }
    }
  }

  private func playSong(at index: Int) {
    pendingIndex = index
    Task {
      do {
        let client = try session.makeClient()
        playback.play(from: index, songs: vm.songs, client: client)
      } catch {
        await MainActor.run {
          vm.errorText = error.localizedDescription
          pendingIndex = nil
        }
      }
    }
  }

  private func refresh() {
    Task {
      do {
        let client = try session.makeClient()
        await vm.refresh(client: client)
      } catch {
        await MainActor.run {
          vm.errorText = error.localizedDescription
        }
      }
    }
  }
}

private struct SongRowView: View {
  let song: Song
  let isCurrent: Bool
  let isPending: Bool
  let onTap: () -> Void

  private var subtitle: String {
    let subtitleArtist = song.artist
    let subtitleAlbum = song.album
    if !subtitleArtist.isEmpty && !subtitleAlbum.isEmpty {
      return "\(subtitleArtist) · \(subtitleAlbum)"
    }
    if !subtitleArtist.isEmpty {
      return subtitleArtist
    }
    if !subtitleAlbum.isEmpty {
      return subtitleAlbum
    }
    return ""
  }

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // 标题 + 副标题
        VStack(alignment: .leading, spacing: 3) {
          Text(song.title.isEmpty ? "(未命名歌曲)" : song.title)
            .font(.body)
            .fontWeight(isCurrent ? .semibold : .regular)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          if !subtitle.isEmpty {
            Text(subtitle)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .opacity(isCurrent ? 1.0 : 0.7)
              .lineLimit(1)
          }
        }

        Spacer()

        // 右侧小菊花
        if isPending {
          ProgressView()
            .scaleEffect(0.8)
        }
      }
      .padding(.vertical, 9)
      .padding(.horizontal, isCurrent ? 8 : 0)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(isCurrent ? Color.accentColor.opacity(0.12) : Color.clear)
  }
}
