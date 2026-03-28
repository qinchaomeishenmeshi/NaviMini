import SwiftUI

import AVFoundation

@main
struct NaviMiniApp: App {
  init() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      MetricsLogger.shared.log("app_audio_session_error error=\(error)")
    }
  }
  var body: some Scene {
    WindowGroup {
      switch LaunchMode.current {
      case .normal:
        ContentView()
      case .screenshotConnect, .screenshotLibrary, .screenshotPlayer:
        ScreenshotShowcaseView(mode: LaunchMode.current)
      }
    }
  }
}
