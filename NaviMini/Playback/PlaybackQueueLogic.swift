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
    isActuallyAdvancing: Bool = true,
    duration: Double?
  ) -> Double {
    let safeBase = max(baseSeconds, 0)
    let safeElapsed = max(elapsedSinceAnchor, 0)
    let projected = isPlaying && isActuallyAdvancing ? safeBase + safeElapsed : safeBase
    return normalizedPlaybackTime(rawCurrentSeconds: projected, duration: duration)
  }

  static func normalizedBufferedTime(
    bufferedSeconds: Double,
    duration: Double?
  ) -> Double {
    guard bufferedSeconds.isFinite else { return 0 }
    let safeBuffered = max(bufferedSeconds, 0)

    guard let duration, duration.isFinite, duration > 0 else {
      return safeBuffered
    }

    return min(safeBuffered, duration)
  }
}
