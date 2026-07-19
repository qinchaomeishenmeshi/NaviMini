import SwiftUI

struct LibraryView: View {
  @ObservedObject var session: SessionStore
  @StateObject private var vm: LibraryViewModel

  @ObservedObject var playback: PlaybackController

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pendingIndex: Int? = nil
  @State private var didAutoRefresh: Bool = false
  @State private var visibleSongIDs: Set<String> = []

  init(session: SessionStore, playback: PlaybackController) {
    self.session = session
    self.playback = playback
    _vm = StateObject(wrappedValue: LibraryViewModel())
  }

  var body: some View {
    ScrollViewReader { proxy in
      List {
        if let error = vm.errorText {
          Section {
            VStack(alignment: .leading, spacing: 10) {
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(.red)
                  .accessibilityHidden(true)
                Text(error)
                  .font(.footnote)
                  .foregroundStyle(.red)
                  .fixedSize(horizontal: false, vertical: true)
              }

              Button("重新加载", action: refresh)
                .font(.subheadline.weight(.semibold))
                .disabled(vm.isRefreshing)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("加载失败：\(error)")
            .accessibilityHint("可使用重新加载按钮重试")
          }
        }

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
          .listRowBackground(isCurrent ? Color.accentColor.opacity(0.12) : Color.clear)
          .onAppear {
            visibleSongIDs.insert(song.id)
            if index == vm.songs.count - 1 {
              if !vm.isLoadingMore && vm.hasMore {
                Task {
                  do {
                    let client = try session.makeClient()
                    await vm.loadMore(client: client)
                  } catch {
                    await MainActor.run {
                      vm.errorText = LibraryViewModel.userFacingMessage(for: error)
                    }
                  }
                }
              }
            }
          }
          .onDisappear {
            visibleSongIDs.remove(song.id)
          }
        }

        if vm.isLoadingMore {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
          .listRowBackground(Color.clear)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("正在加载更多歌曲")
        }
      }
      .listStyle(.inset)
      .navigationTitle("歌曲")
      .overlay {
        if vm.songs.isEmpty {
          if vm.isRefreshing {
            VStack(spacing: 12) {
              ProgressView()
              Text("正在加载歌曲…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("正在加载歌曲")
          } else if vm.errorText == nil {
            ContentUnavailableView(
              "还没有歌曲",
              systemImage: "music.note.list",
              description: Text("点右上角刷新，从你的 Navidrome 拉取列表。")
            )
          }
        }
      }
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
            Label {
              Text(nowPlayingToolbarTitle)
                .lineLimit(1)
            } icon: {
              Image(systemName: "play.circle")
            }
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: 180, alignment: .leading)
          .accessibilityLabel(nowPlayingAccessibilityLabel)
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
        guard !visibleSongIDs.contains(song.id) else { return }

        if reduceMotion {
          proxy.scrollTo(song.id, anchor: .center)
        } else {
          withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(song.id, anchor: .center)
          }
        }
      }
    }
  }

  private var nowPlayingToolbarTitle: String {
    guard let song = playback.current else { return "正在播放" }
    return song.title.isEmpty ? "(未命名歌曲)" : song.title
  }

  private var nowPlayingAccessibilityLabel: String {
    guard let song = playback.current else { return "正在播放" }
    let title = song.title.isEmpty ? "(未命名歌曲)" : song.title
    return "正在播放，\(title)"
  }

  private func playSong(at index: Int) {
    pendingIndex = index
    Task {
      do {
        let client = try session.makeClient()
        playback.play(from: index, songs: vm.songs, client: client)
      } catch {
        await MainActor.run {
          vm.errorText = LibraryViewModel.userFacingMessage(for: error)
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
          vm.errorText = LibraryViewModel.userFacingMessage(for: error)
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

  private var titleText: String {
    song.title.isEmpty ? "(未命名歌曲)" : song.title
  }

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

  private var accessibilityLabelText: String {
    var parts = [titleText]
    if !subtitle.isEmpty {
      parts.append(subtitle)
    }
    if isCurrent {
      parts.append("正在播放")
    } else if isPending {
      parts.append("正在准备播放")
    }
    return parts.joined(separator: "，")
  }

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(titleText)
            .font(.body)
            .fontWeight(isCurrent ? .semibold : .regular)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          if !subtitle.isEmpty {
            Text(subtitle)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }

        Spacer()

        if isPending {
          ProgressView()
            .scaleEffect(0.8)
            .accessibilityHidden(true)
        }
      }
      .padding(.vertical, 9)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabelText)
    .accessibilityHint("轻点以播放")
    .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
  }
}
