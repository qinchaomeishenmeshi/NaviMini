import SwiftUI
import UIKit

struct PlayerView: View {
  @ObservedObject var session: SessionStore
  @ObservedObject var playback: PlaybackController

  var body: some View {
    VStack(spacing: 24) {
      // 封面区域
      coverArtView

      // 曲目信息
      VStack(spacing: 8) {
        Text(playback.current?.title ?? "未播放")
          .font(.title2)
          .fontWeight(.semibold)
          .multilineTextAlignment(.center)
          .lineLimit(2)

        let subtitle = [playback.current?.artist, playback.current?.album]
          .compactMap { $0 }
          .filter { !$0.isEmpty }
          .joined(separator: " · ")

        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity)

      // 播放模式
      Picker("模式", selection: Binding(
        get: { playback.mode },
        set: { newMode in
          do {
            let client = try session.makeClient()
            playback.setMode(newMode, client: client)
          } catch {
            // ignore
          }
        }
      )) {
        ForEach(PlayMode.allCases) { m in
          Text(m.title).tag(m)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)

      // 播放控制
      HStack(spacing: 40) {
        Button {
          do {
            let client = try session.makeClient()
            playback.prev(client: client)
          } catch {}
        } label: {
          Image(systemName: "backward.fill")
            .font(.title2)
        }

        Button {
          playback.togglePlayPause()
        } label: {
          Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
            .font(.largeTitle)
            .padding(16)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(Circle())

        Button {
          do {
            let client = try session.makeClient()
            playback.next(client: client)
          } catch {}
        } label: {
          Image(systemName: "forward.fill")
            .font(.title2)
        }
      }
      .padding(.top, 12)

      Spacer()
    }
    .padding([.horizontal, .bottom])
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
  }

  @State private var coverImage: UIImage? = nil
  @State private var isLoadingCover: Bool = false

  @ViewBuilder
  private var coverArtView: some View {
    if let song = playback.current, let artId = song.coverArt,
       let client = try? session.makeClient() {
      let url = client.coverArtURL(coverArtId: artId)

      ZStack {
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.gray.opacity(0.2))

        if let coverImage {
          Image(uiImage: coverImage)
            .resizable()
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if isLoadingCover {
          ProgressView()
        } else {
          Image(systemName: "music.note")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: 260, height: 260)
      .padding(.top, 24)
      .task(id: artId) {
        isLoadingCover = true
        coverImage = await CoverCache.shared.image(for: artId, url: url)
        isLoadingCover = false
      }
    } else {
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.gray.opacity(0.1))
        .frame(width: 260, height: 260)
        .padding(.top, 24)
    }
  }
}
