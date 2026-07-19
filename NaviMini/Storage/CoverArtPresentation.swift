import Foundation

enum CoverArtPresentation {
  static func shouldApplyLoadedImage(
    isTaskCancelled: Bool,
    requestedCoverArtID: String,
    currentCoverArtID: String?
  ) -> Bool {
    guard !isTaskCancelled else { return false }
    return currentCoverArtID == requestedCoverArtID
  }
}
