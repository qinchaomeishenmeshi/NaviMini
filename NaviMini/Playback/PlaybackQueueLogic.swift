import Foundation

enum PlaybackQueueLogic {
  static func nextIndex(currentIndex: Int, count: Int) -> Int? {
    guard count > 0 else { return nil }
    let next = currentIndex + 1
    return next < count ? next : nil
  }

  static func resolvedPlaybackDuration(metadataDuration: Int?, itemDurationSeconds: Double?) -> Double? {
    if let itemDurationSeconds, itemDurationSeconds.isFinite, itemDurationSeconds > 0 {
      return itemDurationSeconds
    }

    if let metadataDuration, metadataDuration > 0 {
      return Double(metadataDuration)
    }

    return nil
  }

  static func normalizedPlaybackTime(
    rawCurrentSeconds: Double,
    duration: Double?
  ) -> Double {
    guard rawCurrentSeconds.isFinite else { return 0 }
    let safeCurrent = max(rawCurrentSeconds, 0)

    guard let duration, duration.isFinite, duration > 0 else {
      return safeCurrent
    }

    return min(safeCurrent, duration)
  }

  static func projectedPlaybackTime(
    baseSeconds: Double,
    elapsedSinceAnchor: Double,
    isPlaying: Bool,
    duration: Double?
  ) -> Double {
    let safeBase = max(baseSeconds, 0)
    let safeElapsed = max(elapsedSinceAnchor, 0)
    let projected = isPlaying ? safeBase + safeElapsed : safeBase
    return normalizedPlaybackTime(rawCurrentSeconds: projected, duration: duration)
  }
}
