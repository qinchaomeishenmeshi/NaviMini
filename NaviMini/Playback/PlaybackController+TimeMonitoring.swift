import AVFoundation

extension PlaybackController {
  func attachTimeObserver(item: AVPlayerItem) {
    progressTracker.attachTimeObserver(controller: self, item: item)
  }

  func finishQueuePlayback() {
    progressTracker.finishQueuePlayback(controller: self)
  }

  func triggerAbnormalProgressAdvance(reason: String, currentSeconds: Double, duration: Double?) {
    progressTracker.triggerAbnormalProgressAdvance(
      controller: self,
      reason: reason,
      currentSeconds: currentSeconds,
      duration: duration
    )
  }

  func fmt5(_ value: Double) -> String {
    progressTracker.fmt5(value)
  }

  func logPlaybackSnapshot(
    reason: String,
    item: AVPlayerItem,
    rawCurrentSeconds: Double,
    displayedCurrentSeconds: Double,
    duration: Double
  ) {
    progressTracker.logPlaybackSnapshot(
      controller: self,
      reason: reason,
      item: item,
      rawCurrentSeconds: rawCurrentSeconds,
      displayedCurrentSeconds: displayedCurrentSeconds,
      duration: duration
    )
  }

  func redactedURLString(_ raw: String) -> String {
    progressTracker.redactedURLString(raw)
  }

  func trackAccessLogRegression(item: AVPlayerItem, rawCurrentSeconds: Double, duration: Double?) {
    progressTracker.trackAccessLogRegression(
      controller: self,
      item: item,
      rawCurrentSeconds: rawCurrentSeconds,
      duration: duration
    )
  }

  func syncCurrentTimeSnapshot() {
    progressTracker.syncCurrentTimeSnapshot(controller: self)
  }
}
