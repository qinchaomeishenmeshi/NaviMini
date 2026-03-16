import Foundation

enum LaunchMode {
  case normal
  case screenshotLogin
  case screenshotLibrary
  case screenshotPlayer

  static var current: LaunchMode {
    let arguments = ProcessInfo.processInfo.arguments

    if arguments.contains("--screenshot-login") {
      return .screenshotLogin
    }

    if arguments.contains("--screenshot-library") {
      return .screenshotLibrary
    }

    if arguments.contains("--screenshot-player") {
      return .screenshotPlayer
    }

    return .normal
  }
}
