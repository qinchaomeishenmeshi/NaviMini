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
}
