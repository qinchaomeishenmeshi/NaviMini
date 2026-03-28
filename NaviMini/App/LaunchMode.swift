import Foundation

enum LaunchMode {
  case normal
  case screenshotConnect
  case screenshotLibrary
  case screenshotPlayer

  static var current: LaunchMode {
    let arguments = ProcessInfo.processInfo.arguments

    if arguments.contains("--screenshot-connect") || arguments.contains("--screenshot-login") {
      return .screenshotConnect
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
