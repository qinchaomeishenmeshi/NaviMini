import Foundation

enum PlaybackQueueLogic {
  struct NearEndFallbackDecision {
    let stagnantTicks: Int
    let shouldTriggerFallback: Bool
  }

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

  static func nearEndFallbackDecision(
    currentSeconds: Double,
    duration: Double,
    lastObservedProgressSeconds: Double?,
    currentStagnantTicks: Int,
    nearEndWindowSeconds: Double,
    stagnationThreshold: Int
  ) -> NearEndFallbackDecision {
    guard duration.isFinite, duration > 0 else {
      return NearEndFallbackDecision(stagnantTicks: 0, shouldTriggerFallback: false)
    }

    let remaining = duration - currentSeconds
    guard remaining >= 0, remaining <= nearEndWindowSeconds else {
      return NearEndFallbackDecision(stagnantTicks: 0, shouldTriggerFallback: false)
    }

    let stagnantTicks: Int
    if let lastObservedProgressSeconds, abs(currentSeconds - lastObservedProgressSeconds) < 0.01 {
      stagnantTicks = currentStagnantTicks + 1
    } else {
      stagnantTicks = 0
    }

    return NearEndFallbackDecision(
      stagnantTicks: stagnantTicks,
      shouldTriggerFallback: stagnantTicks >= stagnationThreshold
    )
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
