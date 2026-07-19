import SwiftUI
import UIKit

struct PlayerView: View {
  @ObservedObject var session: SessionStore
  @ObservedObject var playback: PlaybackController
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dragProgress: Double = 0
  @State private var isDraggingProgress: Bool = false
  @State private var didTriggerDragHaptic: Bool = false
  @State private var coverImage: UIImage? = nil
  @State private var isLoadingCover: Bool = false

  var body: some View {
    VStack(spacing: 24) {
      coverArtView

      VStack(spacing: 8) {
        Text(playback.current?.title ?? "未播放")
          .font(.title2)
          .fontWeight(.semibold)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .accessibilityAddTraits(.isHeader)

        let subtitle = [playback.current?.artist, playback.current?.album]
          .compactMap { $0 }
          .filter { !$0.isEmpty }
          .joined(separator: " · ")

        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } else if playback.current == nil {
          Text("从歌曲列表点一首开始听")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        if playback.current?.sourceFormatLabel != nil || playback.currentPlaybackSource == .localCache {
          HStack(spacing: 6) {
            if let formatLabel = playback.current?.sourceFormatLabel {
              infoBadge(
                text: formatLabel,
                fill: Color.secondary.opacity(0.08),
                foreground: Color.secondary.opacity(0.85),
                accessibilityLabel: "格式 \(formatLabel)"
              )
            }

            if playback.currentPlaybackSource == .localCache {
              infoBadge(
                text: "本地",
                fill: Color.accentColor.opacity(0.12),
                foreground: Color.accentColor.opacity(0.9),
                accessibilityLabel: "正在播放本地缓存"
              )
            }
          }
        }
      }
      .frame(maxWidth: .infinity)

      TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
        let visualProgress = displayedProgress(at: context.date)
        VStack(spacing: 10) {
          MusicProgressBar(
            duration: playback.currentDuration,
            buffered: playback.bufferedTime,
            progress: visualProgress,
            isDragging: isDraggingProgress,
            reduceMotion: reduceMotion,
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
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("播放进度")
          .accessibilityValue(progressAccessibilityValue(visualProgress))
          .accessibilityAdjustableAction { direction in
            guard playback.currentDuration > 0 else { return }
            let step = max(playback.currentDuration * 0.05, 1)
            switch direction {
            case .increment:
              playback.seek(to: min(visualProgress + step, playback.currentDuration))
            case .decrement:
              playback.seek(to: max(visualProgress - step, 0))
            @unknown default:
              break
            }
          }

          HStack {
            Text(formatTime(visualProgress))
              .foregroundStyle(.primary)
              .accessibilityHidden(true)
            Spacer()
            Text("-\(formatTime(max(playback.currentDuration - visualProgress, 0)))")
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)
          }
          .font(.caption.monospacedDigit().weight(.medium))
        }
        .padding(.horizontal)
      }

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
      .accessibilityLabel("播放模式")

      HStack(spacing: 40) {
        Button {
          do {
            let client = try session.makeClient()
            playback.prev(client: client)
          } catch {}
        } label: {
          Image(systemName: "backward.fill")
            .font(.title2)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("上一首")

        Button {
          playback.togglePlayPause()
        } label: {
          Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
            .font(.largeTitle)
            .frame(width: 76, height: 76)
            .contentShape(Circle())
        }
        .buttonStyle(.borderedProminent)
        .clipShape(Circle())
        .accessibilityLabel(playback.isPlaying ? "暂停" : "播放")

        Button {
          do {
            let client = try session.makeClient()
            playback.next(client: client)
          } catch {}
        } label: {
          Image(systemName: "forward.fill")
            .font(.title2)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("下一首")
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

  @ViewBuilder
  private var coverArtView: some View {
    let corner: CGFloat = 16

    ZStack {
      RoundedRectangle(cornerRadius: corner)
        .fill(Color.secondary.opacity(0.12))

      if let coverImage {
        Image(uiImage: coverImage)
          .resizable()
          .aspectRatio(1, contentMode: .fill)
          .frame(width: 260, height: 260)
          .clipped()
          .clipShape(RoundedRectangle(cornerRadius: corner))
          .accessibilityHidden(true)
      } else if isLoadingCover {
        ProgressView()
          .accessibilityLabel("正在加载封面")
      } else {
        Image(systemName: "music.note")
          .font(.largeTitle)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
    }
    .frame(width: 260, height: 260)
    .padding(.top, 24)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(coverAccessibilityLabel)
    .task(id: playback.current?.coverArt) {
      guard let song = playback.current, let artId = song.coverArt,
            let client = try? session.makeClient() else {
        coverImage = nil
        isLoadingCover = false
        return
      }

      isLoadingCover = true
      coverImage = nil
      let url = client.coverArtURL(coverArtId: artId)
      coverImage = await CoverArtLoader.image(from: url)
      isLoadingCover = false
    }
  }

  private var coverAccessibilityLabel: String {
    if playback.current == nil {
      return "未播放，无封面"
    }
    if coverImage != nil {
      return "专辑封面"
    }
    if isLoadingCover {
      return "正在加载封面"
    }
    return "无封面"
  }

  private func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "--:--" }
    let value = Int(seconds.rounded(.down))
    let minutes = value / 60
    let remain = value % 60
    return String(format: "%d:%02d", minutes, remain)
  }

  private func progressAccessibilityValue(_ seconds: Double) -> String {
    guard playback.currentDuration > 0 else { return "时长未知" }
    return "\(formatTime(seconds))，共 \(formatTime(playback.currentDuration))"  }

  private func displayedProgress(at now: Date) -> Double {
    if isDraggingProgress {
      return min(max(dragProgress, 0), max(playback.currentDuration, 0))
    }

    return PlaybackQueueLogic.projectedPlaybackTime(
      baseSeconds: playback.currentTime,
      elapsedSinceAnchor: now.timeIntervalSince(playback.progressAnchorDate),
      isPlaying: playback.isPlaying,
      isActuallyAdvancing: playback.isPlaybackAdvancing,
      duration: playback.currentDuration > 0 ? playback.currentDuration : nil
    )
  }

  private func infoBadge(
    text: String,
    fill: Color,
    foreground: Color,
    accessibilityLabel: String
  ) -> some View {
    Text(text)
      .font(.caption2.weight(.medium))
      .foregroundStyle(foreground)
      .padding(.horizontal, 6)
      .padding(.vertical, 1)
      .background(
        Capsule()
          .fill(fill)
      )
      .accessibilityLabel(accessibilityLabel)
  }
}

private struct MusicProgressBar: View {
  let duration: Double
  let buffered: Double
  let progress: Double
  let isDragging: Bool
  let reduceMotion: Bool
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

  private var bufferedRatio: Double {
    guard duration > 0, duration.isFinite else { return 0 }
    let clampedBuffered = min(max(buffered, 0), duration)
    return clampedBuffered / duration
  }

  var body: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width, 1)
      let knobX = max(min(width * ratio, width), 0)
      let bufferedX = max(min(width * bufferedRatio, width), 0)
      let knobSize: CGFloat = isDragging ? 16 : 12

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
          .fill(Color.primary.opacity(0.18))
          .frame(width: max(bufferedX, 0), height: 6)

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
          .frame(width: knobSize, height: knobSize)
          .overlay(
            Circle()
              .stroke(Color.accentColor.opacity(0.8), lineWidth: 2)
          )
          .shadow(
            color: Color.black.opacity(isDragging ? 0.22 : 0.12),
            radius: isDragging ? 8 : 4,
            y: 2
          )
          .offset(x: knobX - knobSize / 2)
          .animation(
            reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.82),
            value: isDragging
          )
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
