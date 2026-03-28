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

        let inSeekGraceWindow = controller.progressState.lastManualSeekAt.map { Date().timeIntervalSince($0) < controller.seekGraceSeconds } ?? false
        if !inSeekGraceWindow,
           controller.mode != .repeatOne,
           controller.isPlaying,
           controller.current?.id == controller.progressState.monitoredSongId,
           !controller.progressState.didTriggerNearEndFallback {
          if let last = controller.progressState.lastObservedRawProgressSeconds,
             last > controller.unexpectedRewindMinProgressSeconds,
             rawCurrentSeconds + controller.unexpectedRewindThresholdSeconds < last {
            self.triggerAbnormalProgressAdvance(
              controller: controller,
              reason: "rewind",
              currentSeconds: rawCurrentSeconds,
              duration: resolvedDuration
            )
            return
          }

          if let duration = resolvedDuration,
             duration.isFinite,
             duration > 0,
             rawCurrentSeconds > duration + controller.overflowDurationGraceSeconds {
            self.triggerAbnormalProgressAdvance(
              controller: controller,
              reason: "overflow",
              currentSeconds: rawCurrentSeconds,
              duration: duration
            )
            return
          }
        }

        guard controller.mode != .repeatOne,
              controller.isPlaying,
              controller.current?.id == controller.progressState.monitoredSongId,
              !controller.progressState.didTriggerNearEndFallback,
              let duration = resolvedDuration,
              duration.isFinite,
              duration > 0 else {
          controller.progressState.lastObservedProgressSeconds = currentSeconds
          controller.progressState.lastObservedRawProgressSeconds = rawCurrentSeconds
          controller.progressState.stagnantTicksNearEnd = 0
          return
        }

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
              "time_progress song=\(songId) current_time=\(self.fmt5(currentSeconds)) duration=\(self.fmt5(duration)) remaining=\(self.fmt5(remaining)) stagnant_ticks=\(controller.progressState.stagnantTicksNearEnd)"
            )
          }
        }

        let remaining = duration - currentSeconds
        guard remaining >= 0, remaining <= controller.nearEndFallbackWindowSeconds else {
          controller.progressState.lastObservedProgressSeconds = currentSeconds
          controller.progressState.lastObservedRawProgressSeconds = rawCurrentSeconds
          controller.progressState.stagnantTicksNearEnd = 0
          return
        }

        let waitingReason = controller.player.reasonForWaitingToPlay?.rawValue ?? "nil"
        if timeControlStatus == .waitingToPlayAtSpecifiedRate,
           waitingReason == AVPlayer.WaitingReason.noItemToPlay.rawValue,
           remaining <= controller.nearEndNoItemAdvanceWindowSeconds {
          controller.progressState.didTriggerNearEndFallback = true
          let songId = controller.current?.id ?? "nil"
          MetricsLogger.shared.log(
            "near_end_no_item_trigger mode=\(controller.mode.rawValue) current_song=\(songId) current_index=\(controller.currentIndex) current_time=\(self.fmt5(currentSeconds)) duration=\(self.fmt5(duration)) remaining=\(self.fmt5(remaining))"
          )
          self.logPlaybackSnapshot(
            controller: controller,
            reason: "near_end_no_item_trigger",
            item: item,
            rawCurrentSeconds: rawCurrentSeconds,
            displayedCurrentSeconds: currentSeconds,
            duration: duration
          )
          if let client = controller.lastClient {
            controller.next(client: client)
          } else {
            MetricsLogger.shared.log("near_end_no_item_skip reason=no_client")
          }
          return
        }

        let songId = controller.current?.id ?? "nil"
        MetricsLogger.shared.log(
          "near_end_observed song=\(songId) current_time=\(self.fmt5(currentSeconds)) duration=\(self.fmt5(duration)) remaining=\(self.fmt5(remaining)) last_progress=\(self.fmt5(controller.progressState.lastObservedProgressSeconds ?? -1)) stagnant_ticks=\(controller.progressState.stagnantTicksNearEnd)"
        )

        let itemDurationSeconds = CMTimeGetSeconds(item.duration)
        let hasReliableItemDuration = itemDurationSeconds.isFinite && itemDurationSeconds > 0
        let stagnationThreshold = hasReliableItemDuration
          ? controller.nearEndFallbackStagnationTicks
          : controller.nearEndFallbackStagnationTicksForUnreliableDuration

        let decision = PlaybackQueueLogic.nearEndFallbackDecision(
          currentSeconds: currentSeconds,
          duration: duration,
          lastObservedProgressSeconds: controller.progressState.lastObservedProgressSeconds,
          currentStagnantTicks: controller.progressState.stagnantTicksNearEnd,
          nearEndWindowSeconds: controller.nearEndFallbackWindowSeconds,
          stagnationThreshold: stagnationThreshold
        )
        controller.progressState.stagnantTicksNearEnd = decision.stagnantTicks
        controller.progressState.lastObservedProgressSeconds = currentSeconds
        controller.progressState.lastObservedRawProgressSeconds = rawCurrentSeconds

        if decision.shouldTriggerFallback {
          controller.progressState.didTriggerNearEndFallback = true
          let songId = controller.current?.id ?? "nil"
          MetricsLogger.shared.log(
            "near_end_fallback_trigger mode=\(controller.mode.rawValue) current_song=\(songId) current_index=\(controller.currentIndex) current_time=\(self.fmt5(currentSeconds)) duration=\(self.fmt5(duration)) remaining=\(self.fmt5(remaining)) stagnant_ticks=\(controller.progressState.stagnantTicksNearEnd)"
          )
          self.logPlaybackSnapshot(
            controller: controller,
            reason: "near_end_fallback_trigger",
            item: item,
            rawCurrentSeconds: rawCurrentSeconds,
            displayedCurrentSeconds: currentSeconds,
            duration: duration
          )
          if let client = controller.lastClient {
            controller.next(client: client)
          } else {
            MetricsLogger.shared.log("near_end_fallback_skip reason=no_client")
          }
        }
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

  func triggerAbnormalProgressAdvance(
    controller: PlaybackController,
    reason: String,
    currentSeconds: Double,
    duration: Double?
  ) {
    controller.progressState.didTriggerNearEndFallback = true
    let item = controller.player.currentItem
    let songId = controller.current?.id ?? "nil"
    let durationValue = duration ?? -1
    MetricsLogger.shared.log(
      "progress_anomaly_trigger reason=\(reason) mode=\(controller.mode.rawValue) current_song=\(songId) current_index=\(controller.currentIndex) current_time=\(self.fmt5(currentSeconds)) duration=\(self.fmt5(durationValue))"
    )
    if let item {
      self.logPlaybackSnapshot(
        controller: controller,
        reason: "progress_anomaly_trigger_\(reason)",
        item: item,
        rawCurrentSeconds: currentSeconds,
        displayedCurrentSeconds: controller.currentTime,
        duration: durationValue
      )
    }
    if let client = controller.lastClient {
      controller.next(client: client)
    } else {
      MetricsLogger.shared.log("progress_anomaly_skip reason=no_client")
    }
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
