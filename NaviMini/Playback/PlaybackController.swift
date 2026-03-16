import AVFoundation
import Foundation
import Combine
import MediaPlayer

@MainActor
final class PlaybackController: ObservableObject {
  static let shared = PlaybackController()

  @Published private(set) var current: Song?
  @Published var mode: PlayMode = .order
  @Published private(set) var isPlaying: Bool = false

  private let player = AVQueuePlayer()
  private var queue: [Song] = []
  private var currentIndex: Int = 0
  private var cancellables = Set<AnyCancellable>()

  private var endObserver: Any?
  private var timeObserver: Any?
  private var lastClient: SubsonicClient?
  private var audioSessionObservers: [NSObjectProtocol] = []
  private var playStartTime: Date?
  private var playStartSource: String?

  init() {
    configureAudioSession()
    configureRemoteCommands()
    observeAudioSessionNotifications()
  }

  deinit {
    if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    if let timeObserver { player.removeTimeObserver(timeObserver) }
    audioSessionObservers.forEach { NotificationCenter.default.removeObserver($0) }
  }

  func play(from index: Int, songs: [Song], client: SubsonicClient) {
    guard !songs.isEmpty else { return }

    queue = songs
    currentIndex = max(0, min(index, songs.count - 1))
    lastClient = client

    rebuildQueue(client: client)
    player.play()
    isPlaying = true
    updateNowPlayingInfo(client: client)
  }

  func togglePlayPause() {
    if isPlaying {
      player.pause()
      isPlaying = false
    } else {
      player.play()
      isPlaying = true
    }
    updatePlaybackRate()
  }

  func resumePlayback() {
    guard !isPlaying else { return }
    player.play()
    isPlaying = true
    updatePlaybackRate()
  }

  func shuffleCurrentList(client: SubsonicClient) {
    guard !queue.isEmpty else { return }
    mode = .shuffle
    queue.shuffle()
    currentIndex = 0
    rebuildQueue(client: client)
    player.play()
    isPlaying = true
    updateNowPlayingInfo(client: client)
  }

  func startFirstIfNeeded(client: SubsonicClient) async throws {
    if queue.isEmpty {
      let songs = try await client.searchAllSongs(songCount: 50, songOffset: 0)
      guard !songs.isEmpty else { return }
      queue = songs
      currentIndex = 0
    }
    rebuildQueue(client: client)
    player.play()
    isPlaying = true
    updateNowPlayingInfo(client: client)
  }

  func next(client: SubsonicClient) {
    guard !queue.isEmpty else { return }
    guard let nextIndex = PlaybackQueueLogic.nextIndex(currentIndex: currentIndex, count: queue.count) else {
      finishQueuePlayback()
      return
    }

    currentIndex = nextIndex
    rebuildQueue(client: client)
    player.play()
    isPlaying = true
    updateNowPlayingInfo(client: client)
  }

  func prev(client: SubsonicClient) {
    guard !queue.isEmpty else { return }

    currentIndex = max(currentIndex - 1, 0)
    rebuildQueue(client: client)
    player.play()
    isPlaying = true
    updateNowPlayingInfo(client: client)
  }

  func setMode(_ newMode: PlayMode, client: SubsonicClient) {
    guard mode != newMode else { return }
    mode = newMode

    // If shuffle, reshuffle while keeping current song at front.
    if mode == .shuffle, let cur = current {
      var rest = queue.filter { $0.id != cur.id }
      rest.shuffle()
      queue = [cur] + rest
      currentIndex = 0
    }

    rebuildQueue(client: client)
    updateNowPlayingInfo(client: client)
  }

  private func rebuildQueue(client: SubsonicClient, forceRemote: Bool = false) {
    player.removeAllItems()

    let song = queue[currentIndex]
    current = song

    let item: AVPlayerItem
    let isLocal: Bool
    if !forceRemote, let localURL = AudioCache.shared.localURL(for: song.id) {
      item = AVPlayerItem(url: localURL)
      isLocal = true
      player.insert(item, after: nil)
    } else {
      let url = client.streamURL(songId: song.id, format: "mp3", maxBitRate: 192)
      item = AVPlayerItem(url: url)
      isLocal = false
      player.insert(item, after: nil)
      AudioCache.shared.cacheStream(url: url, songId: song.id)
    }

    playStartTime = Date()
    playStartSource = isLocal ? "local" : "remote"

    updateNowPlayingInfo(client: client, elapsedTime: 0)

    // repeat-one behavior
    if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        if self.mode == .repeatOne {
          item.seek(to: .zero, completionHandler: nil)
          self.player.play()
          self.isPlaying = true
          self.updatePlaybackRate()
        } else {
          self.next(client: client)
        }
      }
    }

    // Monitor for failure status to help debug why nothing plays
    item.publisher(for: \.status)
      .sink { [weak self] status in
        guard let self else { return }
        if status == .readyToPlay, let start = self.playStartTime {
          let durationMs = Int(Date().timeIntervalSince(start) * 1000)
          let source = self.playStartSource ?? "unknown"
          MetricsLogger.shared.log("play_start_ready songId=\(song.id) source=\(source) duration_ms=\(durationMs)")
          self.playStartTime = nil
          self.playStartSource = nil
          self.updateNowPlayingInfo(client: client, elapsedTime: 0, itemDuration: item.duration)
          if !isLocal {
            let url = client.streamURL(songId: song.id, format: "mp3", maxBitRate: 192)
            AudioCache.shared.enqueueDownload(songId: song.id, url: url)
          }
        }
        if status == .failed, let error = item.error {
          print("Playback error on item: \(error.localizedDescription)")
          print("Error details: \(String(describing: item.error))")
          if isLocal {
            print("[AudioCache] local playback failed, fallback to remote for songId=\(song.id)")
            AudioCache.shared.invalidate(songId: song.id)
            self.rebuildQueue(client: client, forceRemote: true)
            self.player.play()
            self.isPlaying = true
            self.updateNowPlayingInfo(client: client, elapsedTime: 0)
          }
        }
      }
      .store(in: &cancellables)

    attachTimeObserver(item: item)
  }
}

// MARK: - Background Audio & Now Playing
private extension PlaybackController {
  func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [])
      try session.setActive(true)
    } catch {
      print("[AudioSession] error: \(error.localizedDescription)")
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
    guard let song = current else { return }

    var info: [String: Any] = [
      MPMediaItemPropertyTitle: song.title,
      MPMediaItemPropertyArtist: song.artist,
      MPMediaItemPropertyAlbumTitle: song.album,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
      MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
    ]

    let itemDurationSeconds = itemDuration.map(CMTimeGetSeconds)
    if let duration = PlaybackQueueLogic.resolvedPlaybackDuration(
      metadataDuration: song.duration,
      itemDurationSeconds: itemDurationSeconds
    ) {
      info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: duration)
    }

    MPNowPlayingInfoCenter.default().nowPlayingInfo = info

    if let artId = song.coverArt {
      let url = client.coverArtURL(coverArtId: artId)
      Task {
        if let image = await CoverCache.shared.image(for: artId, url: url) {
          let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
          var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
          currentInfo[MPMediaItemPropertyArtwork] = artwork
          MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
        }
      }
    }
  }

  func updatePlaybackRate() {
    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
    info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  func attachTimeObserver(item: AVPlayerItem) {
    if let timeObserver {
      player.removeTimeObserver(timeObserver)
      self.timeObserver = nil
    }
    let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
      let currentSeconds = CMTimeGetSeconds(item.currentTime())
      guard !currentSeconds.isNaN else { return }
      Task { @MainActor [weak self] in
        guard let self else { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentSeconds
        if let duration = PlaybackQueueLogic.resolvedPlaybackDuration(
          metadataDuration: self.current?.duration,
          itemDurationSeconds: CMTimeGetSeconds(item.duration)
        ) {
          info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      }
    }
  }

  func finishQueuePlayback() {
    player.pause()
    isPlaying = false
    updatePlaybackRate()
  }
}
