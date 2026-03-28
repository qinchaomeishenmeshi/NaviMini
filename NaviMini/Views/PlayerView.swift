import SwiftUI
import UIKit

struct PlayerView: View {
  @ObservedObject var session: SessionStore
  @ObservedObject var playback: PlaybackController
  @State private var dragProgress: Double = 0
  @State private var isDraggingProgress: Bool = false
  @State private var didTriggerDragHaptic: Bool = false

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

      TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
        let visualProgress = displayedProgress(at: context.date)
        VStack(spacing: 10) {
          ZStack(alignment: .center) {
            MusicProgressBar(
              duration: playback.currentDuration,
              progress: visualProgress,
              isDragging: isDraggingProgress,
              onDragChanged: { value in
                if !isDraggingProgress {
                  isDraggingProgress = true
                  dragProgress = playback.currentTime
                }
                dragProgress = value
                if !didTriggerDragHaptic {
                  UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                  didTriggerDragHaptic = true
                }
              },
              onDragEnded: {
                isDraggingProgress = false
                didTriggerDragHaptic = false
                playback.seek(to: dragProgress)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
              }
            )
            .frame(height: 36)
            .opacity(playback.currentDuration > 0 ? 1 : 0.5)
            .allowsHitTesting(playback.currentDuration > 0)
          }

          HStack {
            Text(formatTime(visualProgress))
              .foregroundStyle(.primary)
            Spacer()
            Text("-\(formatTime(max(playback.currentDuration - visualProgress, 0)))")
              .foregroundStyle(.secondary)
          }
          .font(.caption.monospacedDigit().weight(.medium))
        }
        .padding(.horizontal)
      }

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
    .onChange(of: playback.current?.id) { _, _ in
      dragProgress = 0
      isDraggingProgress = false
    }
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

  private func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "--:--" }
    let value = Int(seconds.rounded(.down))
    let minutes = value / 60
    let remain = value % 60
    return String(format: "%d:%02d", minutes, remain)
  }

  private func displayedProgress(at now: Date) -> Double {
    if isDraggingProgress {
      return min(max(dragProgress, 0), max(playback.currentDuration, 0))
    }

    return PlaybackQueueLogic.projectedPlaybackTime(
      baseSeconds: playback.currentTime,
      elapsedSinceAnchor: now.timeIntervalSince(playback.progressAnchorDate),
      isPlaying: playback.isPlaying,
      duration: playback.currentDuration > 0 ? playback.currentDuration : nil
    )
  }
}

private struct MusicProgressBar: View {
  let duration: Double
  let progress: Double
  let isDragging: Bool
  let onDragChanged: (Double) -> Void
  let onDragEnded: () -> Void

  private var clampedProgress: Double {
    guard duration > 0, duration.isFinite else { return 0 }
    return min(max(progress, 0), duration)
  }

  private var ratio: Double {
    guard duration > 0, duration.isFinite else { return 0 }
    return clampedProgress / duration
  }

  var body: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width, 1)
      let knobX = max(min(width * ratio, width), 0)

      ZStack(alignment: .leading) {
        Capsule()
          .fill(
            LinearGradient(
              colors: [
                Color.primary.opacity(0.12),
                Color.primary.opacity(0.06)
              ],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(height: 6)

        Capsule()
          .fill(
            LinearGradient(
              colors: [
                Color.accentColor.opacity(0.95),
                Color.accentColor.opacity(0.65)
              ],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: max(knobX, 0), height: 6)

        Circle()
          .fill(Color.white)
          .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
          .overlay(
            Circle()
              .stroke(Color.accentColor.opacity(0.8), lineWidth: 2)
          )
          .shadow(color: Color.black.opacity(isDragging ? 0.22 : 0.12), radius: isDragging ? 8 : 4, y: 2)
          .offset(x: knobX - (isDragging ? 8 : 6))
          .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isDragging)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            guard duration > 0 else { return }
            let locationX = min(max(value.location.x, 0), width)
            let next = (locationX / width) * duration
            onDragChanged(next)
          }
          .onEnded { _ in
            guard duration > 0 else { return }
            onDragEnded()
          }
      )
    }
  }
}
