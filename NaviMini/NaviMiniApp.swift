import SwiftUI

import AVFoundation

@main
struct NaviMiniApp: App {
  init() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Failed to set audio session category: \(error)")
    }
  }
  var body: some Scene {
    WindowGroup {
      switch LaunchMode.current {
      case .normal:
        ContentView()
      case .screenshotLogin, .screenshotLibrary, .screenshotPlayer:
        ScreenshotShowcaseView(mode: LaunchMode.current)
      }
    }
  }
}
