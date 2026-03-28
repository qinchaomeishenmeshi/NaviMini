import AVFoundation
import Foundation
import MediaPlayer

@MainActor
final class PlaybackProgressTracker {
  func attachTimeObserver(controller: PlaybackController, item: AVPlayerItem) {
    if let timeObserver = controller.observerState.timeObserver {
      controller.player.removeTimeObserver(timeObserver)
      controller.observerState.timeObserver = nil
    }
    let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    controller.observerState.timeObserver = controller.player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self, weak controller] _ in
      guard let self, let controller else { return }
      guard controller.player.currentItem === item else { return }
      let rawCurrentSeconds = CMTimeGetSeconds(controller.player.currentTime())
      guard !rawCurrentSeconds.isNaN else { return }
      Task { @MainActor [weak self, weak controller] in
        guard let self, let controller else { return }

        let timeControlStatus = controller.player.timeControlStatus
        if controller.observerState.lastLoggedTimeControlStatus != timeControlStatus {
          controller.observerState.lastLoggedTimeControlStatus = timeControlStatus
          let waitingReason = controller.player.reasonForWaitingToPlay?.rawValue ?? "nil"
          let songId = controller.current?.id ?? "nil"
          MetricsLogger.shared.log(
            "time_control_changed status=\(timeControlStatus.rawValue) reason=\(waitingReason) current_song=\(songId) current_index=\(controller.currentIndex)"
          )
        }

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        let resolvedDuration = PlaybackQueueLogic.resolvedPlaybackDuration(
          metadataDuration: controller.current?.duration,
          itemDurationSeconds: CMTimeGetSeconds(item.duration)
        )
        let currentSeconds = PlaybackQueueLogic.normalizedPlaybackTime(
          rawCurrentSeconds: rawCurrentSeconds,
          duration: resolvedDuration
        )
        let duration = resolvedDuration ?? 0
        self.trackAccessLogRegression(controller: controller, item: item, rawCurrentSeconds: rawCurrentSeconds, duration: resolvedDuration)
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentSeconds
        controller.currentTime = currentSeconds
        controller.currentDuration = resolvedDuration ?? 0
        controller.progressAnchorDate = Date()
        if let duration = resolvedDuration {
          info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = controller.isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        if currentSeconds > 0 {
          let ticks = Int(currentSeconds)
          if ticks > 0, ticks % 5 == 0, ticks != controller.observerState.lastSnapshotTick {
            controller.observerState.lastSnapshotTick = ticks
            self.logPlaybackSnapshot(
              controller: controller,
              reason: "periodic_5s_snapshot",
              item: item,
              rawCurrentSeconds: rawCurrentSeconds,
              displayedCurrentSeconds: currentSeconds,
              duration: duration
            )
          }
          if ticks > 0, ticks % 10 == 0, ticks != controller.observerState.lastLoggedProgressTick {
            controller.observerState.lastLoggedProgressTick = ticks
            let remaining = duration - currentSeconds
            let songId = controller.current?.id ?? "nil"
            MetricsLogger.shared.log(
              "time_progress song=\(songId) current_time=\(self.fmt5(currentSeconds)) duration=\(self.fmt5(duration)) remaining=\(self.fmt5(remaining))"
            )
          }
        }
        let songId = controller.current?.id ?? "nil"
        MetricsLogger.shared.log(
          "playback_progress song=\(songId) current_time=\(self.fmt5(currentSeconds)) duration=\(self.fmt5(duration)) time_control=\(timeControlStatus.rawValue)"
        )
      }
    }
  }

  func finishQueuePlayback(controller: PlaybackController) {
    let currentSongId = controller.current?.id ?? "nil"
    MetricsLogger.shared.log(
      "finish_queue mode=\(controller.mode.rawValue) current_index=\(controller.currentIndex) current_song=\(currentSongId) queue_count=\(controller.queue.count)"
    )
    controller.player.pause()
    controller.isPlaying = false
    self.syncCurrentTimeSnapshot(controller: controller)
    controller.updatePlaybackRate()
  }

  func logPlaybackSnapshot(
    controller: PlaybackController,
    reason: String,
    item: AVPlayerItem,
    rawCurrentSeconds: Double,
    displayedCurrentSeconds: Double,
    duration: Double
  ) {
    let accessEvent = item.accessLog()?.events.last
    let errorEvent = item.errorLog()?.events.last
    let queueCount = controller.queue.count
    let songId = controller.current?.id ?? "nil"
    let waitingReason = controller.player.reasonForWaitingToPlay?.rawValue ?? "nil"
    let timeControlStatus = controller.player.timeControlStatus.rawValue
    let uri = accessEvent?.uri.flatMap(self.redactedURLString) ?? "nil"
    let responseURL = item.asset as? AVURLAsset
    let streamURL = responseURL.map { self.redactedURLString($0.url.absoluteString) } ?? "nil"
    let serverAddress = accessEvent?.serverAddress ?? "nil"
    let requests = accessEvent.map { String($0.numberOfMediaRequests) } ?? "nil"
    let segments = accessEvent.map { self.fmt5($0.segmentsDownloadedDuration) } ?? "nil"
    let observedBitrate = accessEvent.map { self.fmt5($0.observedBitrate) } ?? "nil"
    let indicatedBitrate = accessEvent.map { self.fmt5($0.indicatedBitrate) } ?? "nil"
    let stalls = accessEvent.map { String($0.numberOfStalls) } ?? "nil"
    let transferDuration = accessEvent.map { self.fmt5($0.transferDuration) } ?? "nil"
    let bytesTransferred = accessEvent.map { String($0.numberOfBytesTransferred) } ?? "nil"
    let errorStatus = errorEvent?.errorStatusCode ?? 0
    let errorDomain = errorEvent?.errorDomain ?? "nil"
    let errorComment = errorEvent?.errorComment ?? "nil"

    MetricsLogger.shared.log(
      """
      playback_snapshot reason=\(reason) song=\(songId) index=\(controller.currentIndex) queue_count=\(queueCount) \
      is_playing=\(controller.isPlaying) time_control=\(timeControlStatus) waiting_reason=\(waitingReason) \
      raw_time=\(self.fmt5(rawCurrentSeconds)) display_time=\(self.fmt5(displayedCurrentSeconds)) duration=\(self.fmt5(duration)) \
      stream_url=\(streamURL) access_uri=\(uri) server=\(serverAddress) media_requests=\(requests) \
      segments_downloaded=\(segments) observed_bitrate=\(observedBitrate) indicated_bitrate=\(indicatedBitrate) \
      stalls=\(stalls) transfer_duration=\(transferDuration) bytes=\(bytesTransferred) \
      error_domain=\(errorDomain) error_status=\(errorStatus) error_comment=\(errorComment)
      """
    )
  }

  func redactedURLString(_ raw: String) -> String {
    guard var components = URLComponents(string: raw) else { return raw }
    components.query = nil
    components.fragment = nil
    return components.string ?? raw
  }

  func trackAccessLogRegression(controller: PlaybackController, item: AVPlayerItem, rawCurrentSeconds: Double, duration: Double?) {
    guard let event = item.accessLog()?.events.last else { return }
    let segmentsDownloaded = event.segmentsDownloadedDuration
    let mediaRequestCount = event.numberOfMediaRequests

    defer {
      controller.progressState.lastObservedSegmentsDownloadedDuration = segmentsDownloaded
      controller.progressState.lastObservedMediaRequestCount = mediaRequestCount
    }

    guard let lastSegments = controller.progressState.lastObservedSegmentsDownloadedDuration else { return }
    let segmentRegression = lastSegments - segmentsDownloaded
    if segmentRegression > 1.0, rawCurrentSeconds > 10 {
      let songId = controller.current?.id ?? "nil"
      let durationValue = duration ?? -1
      MetricsLogger.shared.log(
        "stream_regression_detected song=\(songId) raw_time=\(self.fmt5(rawCurrentSeconds)) duration=\(self.fmt5(durationValue)) segments_prev=\(self.fmt5(lastSegments)) segments_now=\(self.fmt5(segmentsDownloaded)) delta=\(self.fmt5(segmentRegression)) media_requests_prev=\(controller.progressState.lastObservedMediaRequestCount ?? -1) media_requests_now=\(mediaRequestCount)"
      )
      self.logPlaybackSnapshot(
        controller: controller,
        reason: "stream_regression_detected",
        item: item,
        rawCurrentSeconds: rawCurrentSeconds,
        displayedCurrentSeconds: controller.currentTime,
        duration: durationValue
      )
    }
  }

  func syncCurrentTimeSnapshot(controller: PlaybackController) {
    let rawCurrentSeconds = CMTimeGetSeconds(controller.player.currentTime())
    guard !rawCurrentSeconds.isNaN else { return }
    let snapped = PlaybackQueueLogic.normalizedPlaybackTime(
      rawCurrentSeconds: rawCurrentSeconds,
      duration: controller.currentDuration > 0 ? controller.currentDuration : nil
    )
    controller.currentTime = snapped
    controller.progressAnchorDate = Date()
  }

  func fmt5(_ value: Double) -> String {
    guard value.isFinite else { return "nan" }
    return String(format: "%.5f", value)
  }
}
