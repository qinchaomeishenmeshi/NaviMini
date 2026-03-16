import SwiftUI

struct ScreenshotShowcaseView: View {
  let mode: LaunchMode

  var body: some View {
    NavigationStack {
      switch mode {
      case .screenshotLogin:
        ScreenshotLoginView()
      case .screenshotLibrary:
        ScreenshotLibraryView()
      case .screenshotPlayer:
        ScreenshotPlayerView()
      case .normal:
        EmptyView()
      }
    }
  }
}

private struct ScreenshotLoginView: View {
  var body: some View {
    VStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text("连接到你的 Navidrome 资料库")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal)

      Form {
        Section("服务器") {
          Text("https://your-domain.example.com/rest")
            .foregroundStyle(.primary)
        }

        Section("帐户") {
          Text("用户名")
            .foregroundStyle(.secondary)
          Text("密码")
            .foregroundStyle(.secondary)
        }

        Section {
          HStack {
            Spacer()
            Text("登录")
              .fontWeight(.semibold)
              .foregroundStyle(.white)
            Spacer()
          }
          .padding(.vertical, 8)
          .background(Color.blue, in: RoundedRectangle(cornerRadius: 8))
        }
        .listRowBackground(Color.clear)
      }
      .formStyle(.grouped)
    }
    .navigationTitle("连接资料库")
  }
}

private struct ScreenshotLibraryView: View {
  private let songs: [Song] = [
    Song(id: "song-1", title: "Misty Platform", artist: "NaviMini", album: "Demo Session", duration: 228, coverArt: nil),
    Song(id: "song-2", title: "Signal Over Water", artist: "QZX", album: "Evening Cache", duration: 241, coverArt: nil),
    Song(id: "song-3", title: "Silent Reindex", artist: "Navidrome", album: "Library Sync", duration: 205, coverArt: nil),
    Song(id: "song-4", title: "Blue Control Center", artist: "Playback", album: "Background Audio", duration: 252, coverArt: nil),
    Song(id: "song-5", title: "No More Last-Track Loop", artist: "Regression Fix", album: "March Build", duration: 198, coverArt: nil),
    Song(id: "song-6", title: "Cover Cache", artist: "Storage Layer", album: "Warm Disk", duration: 216, coverArt: nil)
  ]

  var body: some View {
    List {
      ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
        ScreenshotSongRowView(song: song, isCurrent: index == 1)
      }
    }
    .listStyle(.inset)
    .navigationTitle("歌曲")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Label("正在播放", systemImage: "play.circle")
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(.blue.opacity(0.14), in: Capsule())
      }

      ToolbarItem(placement: .topBarTrailing) {
        Image(systemName: "arrow.clockwise.circle")
          .font(.title3)
      }
    }
  }
}

private struct ScreenshotSongRowView: View {
  let song: Song
  let isCurrent: Bool

  private var subtitle: String {
    "\(song.artist) · \(song.album)"
  }

  var body: some View {
    HStack(spacing: 12) {
      RoundedRectangle(cornerRadius: 10)
        .fill(
          LinearGradient(
            colors: isCurrent ? [.blue.opacity(0.9), .cyan.opacity(0.8)] : [.gray.opacity(0.25), .gray.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 44, height: 44)
        .overlay {
          Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
            .foregroundStyle(isCurrent ? .white : .secondary)
        }

      VStack(alignment: .leading, spacing: 4) {
        Text(song.title)
          .font(.body)
          .fontWeight(isCurrent ? .semibold : .regular)
          .lineLimit(2)

        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      if isCurrent {
        Text("正在播放")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundStyle(.blue)
      } else {
        Text(formattedDuration(song.duration))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 8)
    .listRowBackground(isCurrent ? Color.blue.opacity(0.08) : Color.clear)
  }

  private func formattedDuration(_ duration: Int?) -> String {
    guard let duration else { return "--:--" }
    let minutes = duration / 60
    let seconds = duration % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}

private struct ScreenshotPlayerView: View {
  var body: some View {
    VStack(spacing: 24) {
      RoundedRectangle(cornerRadius: 24)
        .fill(
          LinearGradient(
            colors: [Color.blue.opacity(0.95), Color.cyan.opacity(0.75), Color.indigo.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 280, height: 280)
        .overlay(alignment: .bottomLeading) {
          VStack(alignment: .leading, spacing: 8) {
            Text("NaviMini")
              .font(.headline)
              .foregroundStyle(.white.opacity(0.9))
            Text("Demo Session")
              .font(.title3.weight(.bold))
              .foregroundStyle(.white)
          }
          .padding(20)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .padding(.top, 28)

      VStack(spacing: 8) {
        Text("Signal Over Water")
          .font(.title2)
          .fontWeight(.semibold)
          .multilineTextAlignment(.center)

        Text("QZX · Evening Cache")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)

      VStack(spacing: 12) {
        HStack {
          Text("1:24")
          Spacer()
          Text("4:01")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)

        VStack(spacing: 0) {
          Capsule()
            .fill(Color.blue)
            .frame(width: 150, height: 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              Capsule()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 5)
            )
        }
        .padding(.horizontal)
      }

      Picker("模式", selection: .constant("顺序")) {
        Text("顺序").tag("顺序")
        Text("随机").tag("随机")
        Text("单曲循环").tag("单曲循环")
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)

      HStack(spacing: 40) {
        Image(systemName: "backward.fill")
          .font(.title2)

        ZStack {
          Circle()
            .fill(Color.blue)
            .frame(width: 76, height: 76)
          Image(systemName: "pause.fill")
            .font(.title)
            .foregroundStyle(.white)
        }

        Image(systemName: "forward.fill")
          .font(.title2)
      }
      .padding(.top, 8)

      Spacer()
    }
    .padding([.horizontal, .bottom])
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
  }
}
