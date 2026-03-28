import AVFoundation
import Foundation
import MediaPlayer

extension PlaybackController {
  func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [])
      try session.setActive(true)
    } catch {
      MetricsLogger.shared.log("audio_session_error error=\(error.localizedDescription)")
    }
  }

  func observeAudioSessionNotifications() {
    let center = NotificationCenter.default
    let interruption = center.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: nil,
      queue: .main
    ) { notification in
      guard let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
      switch type {
      case .began:
        break
      case .ended:
        let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        if options.contains(.shouldResume) {
          Task { @MainActor [weak self] in
            guard let self else { return }
            self.player.play()
            self.isPlaying = true
            self.updatePlaybackRate()
          }
        }
      @unknown default:
        break
      }
    }

    let routeChange = center.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
    }

    audioSessionObservers = [interruption, routeChange]
  }

  func configureRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()

    center.playCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      if !self.isPlaying {
        self.player.play()
        self.isPlaying = true
        self.updatePlaybackRate()
      }
      return .success
    }

    center.pauseCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      if self.isPlaying {
        self.player.pause()
        self.isPlaying = false
        self.updatePlaybackRate()
      }
      return .success
    }

    center.nextTrackCommand.addTarget { [weak self] _ in
      guard let self, let client = self.lastClient else { return .commandFailed }
      self.next(client: client)
      return .success
    }

    center.previousTrackCommand.addTarget { [weak self] _ in
      guard let self, let client = self.lastClient else { return .commandFailed }
      self.prev(client: client)
      return .success
    }
  }

  func updateNowPlayingInfo(client: SubsonicClient, elapsedTime: Double = 0, itemDuration: CMTime? = nil) {
    nowPlayingCoordinator.update(
      song: current,
      isPlaying: isPlaying,
      client: client,
      elapsedTime: elapsedTime,
      itemDuration: itemDuration
    )
  }

  func updatePlaybackRate() {
    nowPlayingCoordinator.updatePlaybackRate(isPlaying: isPlaying)
  }
}
