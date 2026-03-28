import AVFoundation
import Foundation
import Combine
import MediaPlayer

@MainActor
final class PlaybackController: ObservableObject {
  static let shared = PlaybackController()

  @Published var current: Song?
  @Published var mode: PlayMode = .order
  @Published var isPlaying: Bool = false
  @Published var currentTime: Double = 0
  @Published var currentDuration: Double = 0
  @Published var progressAnchorDate: Date = Date()

  let player = AVQueuePlayer()
  var queue: [Song] = []
  var currentIndex: Int = 0
  var observerState = PlaybackObserverState()
  var progressState = PlaybackProgressState()
  let nowPlayingCoordinator = PlaybackNowPlayingCoordinator()
  let progressTracker = PlaybackProgressTracker()
  let queueItemFactory = PlaybackQueueItemFactory()
  var lastClient: SubsonicClient?
  var audioSessionObservers: [NSObjectProtocol] = []
  var playStartTime: Date?
  var playStartSource: String?

  let nearEndFallbackWindowSeconds: Double = 1.5
  let nearEndFallbackStagnationTicks: Int = 5
  let nearEndFallbackStagnationTicksForUnreliableDuration: Int = 2
  let unexpectedRewindThresholdSeconds: Double = 5
  let unexpectedRewindMinProgressSeconds: Double = 20
  let overflowDurationGraceSeconds: Double = 6
  let seekGraceSeconds: Double = 2.5
  let nearEndNoItemAdvanceWindowSeconds: Double = 1.2

  init() {
    configureAudioSession()
    configureRemoteCommands()
    observeAudioSessionNotifications()
  }

  deinit {
    observerState.clearObservers(using: player)
    audioSessionObservers.forEach { NotificationCenter.default.removeObserver($0) }
  }

  private func startPlayback(
    client: SubsonicClient,
    elapsedTime: Double = 0,
    itemDuration: CMTime? = nil
  ) {
    progressAnchorDate = Date()
    player.play()
    isPlaying = true
    updateNowPlayingInfo(client: client, elapsedTime: elapsedTime, itemDuration: itemDuration)
  }

  private func resumePlaybackState() {
    progressAnchorDate = Date()
    player.play()
    isPlaying = true
    updatePlaybackRate()
  }

  private func pausePlaybackState() {
    syncCurrentTimeSnapshot()
    player.pause()
    isPlaying = false
    updatePlaybackRate()
  }

  private func transitionToCurrentIndex(client: SubsonicClient) {
    rebuildQueue(client: client)
    startPlayback(client: client)
  }

  private func reshuffleQueueKeepingCurrentSong() {
    guard let cur = current else { return }
    var rest = queue.filter { $0.id != cur.id }
    rest.shuffle()
    queue = [cur] + rest
    currentIndex = 0
  }

  func play(from index: Int, songs: [Song], client: SubsonicClient) {
    guard !songs.isEmpty else { return }

    queue = songs
    currentIndex = max(0, min(index, songs.count - 1))
    lastClient = client

    let selectedSongId = queue[currentIndex].id
    let uniqueSongCount = Set(queue.map(\.id)).count
    MetricsLogger.shared.log(
      "play_request index=\(index) clamped_index=\(currentIndex) selected_song=\(selectedSongId) queue_count=\(queue.count) unique_song_count=\(uniqueSongCount) mode=\(mode.rawValue)"
    )

    transitionToCurrentIndex(client: client)
  }

  func togglePlayPause() {
    if isPlaying {
      pausePlaybackState()
    } else {
      resumePlaybackState()
    }
  }

  func resumePlayback() {
    guard !isPlaying else { return }
    resumePlaybackState()
  }

  func shuffleCurrentList(client: SubsonicClient) {
    guard !queue.isEmpty else { return }
    mode = .shuffle
    queue.shuffle()
    currentIndex = 0
    transitionToCurrentIndex(client: client)
  }

  func startFirstIfNeeded(client: SubsonicClient) async throws {
    if queue.isEmpty {
      let songs = try await client.searchAllSongs(songCount: 50, songOffset: 0)
      guard !songs.isEmpty else { return }
      queue = songs
      currentIndex = 0
    }
    transitionToCurrentIndex(client: client)
  }

  func seek(to seconds: Double) {
    guard let item = player.currentItem else { return }
    let targetSeconds: Double
    if currentDuration > 0, currentDuration.isFinite {
      targetSeconds = min(max(seconds, 0), currentDuration)
    } else {
      targetSeconds = max(seconds, 0)
    }
    let target = CMTime(seconds: targetSeconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    item.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: nil)
    progressState.lastManualSeekAt = Date()
    progressAnchorDate = Date()
    currentTime = targetSeconds
    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = targetSeconds
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  func next(client: SubsonicClient) {
    guard !queue.isEmpty else {
      MetricsLogger.shared.log("next_request queue_empty=true")
      return
    }
    let previousIndex = currentIndex
    let previousSongId = queue[previousIndex].id
    guard let nextIndex = PlaybackQueueLogic.nextIndex(currentIndex: currentIndex, count: queue.count) else {
      MetricsLogger.shared.log(
        "next_request reached_end=true mode=\(mode.rawValue) current_index=\(currentIndex) current_song=\(previousSongId) queue_count=\(queue.count)"
      )
      finishQueuePlayback()
      return
    }

    let nextSongId = queue[nextIndex].id
    MetricsLogger.shared.log(
      "next_request reached_end=false mode=\(mode.rawValue) from_index=\(previousIndex) from_song=\(previousSongId) to_index=\(nextIndex) to_song=\(nextSongId) queue_count=\(queue.count)"
    )

    currentIndex = nextIndex
    transitionToCurrentIndex(client: client)
  }

  func prev(client: SubsonicClient) {
    guard !queue.isEmpty else {
      MetricsLogger.shared.log("prev_request queue_empty=true")
      return
    }

    let previousIndex = currentIndex
    let previousSongId = queue[previousIndex].id
    let targetIndex = max(currentIndex - 1, 0)
    let targetSongId = queue[targetIndex].id
    MetricsLogger.shared.log(
      "prev_request mode=\(mode.rawValue) from_index=\(previousIndex) from_song=\(previousSongId) to_index=\(targetIndex) to_song=\(targetSongId) queue_count=\(queue.count)"
    )

    currentIndex = targetIndex
    transitionToCurrentIndex(client: client)
  }

  func setMode(_ newMode: PlayMode, client: SubsonicClient) {
    guard mode != newMode else { return }
    let oldMode = mode
    mode = newMode

    // If shuffle, reshuffle while keeping current song at front.
    if mode == .shuffle {
      reshuffleQueueKeepingCurrentSong()
    }

    let currentSongId = current?.id ?? "nil"
    MetricsLogger.shared.log(
      "mode_change from=\(oldMode.rawValue) to=\(newMode.rawValue) current_index=\(currentIndex) current_song=\(currentSongId) queue_count=\(queue.count)"
    )

    rebuildQueue(client: client)
    updateNowPlayingInfo(client: client)
  }

  private func rebuildQueue(client: SubsonicClient, forceRemote: Bool = false) {
    player.removeAllItems()
    observerState.cancellables.removeAll()

    let song = queue[currentIndex]
    current = song
    currentTime = 0
    currentDuration = 0
    progressAnchorDate = Date()

    let uniqueSongCount = Set(queue.map(\.id)).count
    MetricsLogger.shared.log(
      "rebuild_queue mode=\(mode.rawValue) current_index=\(currentIndex) current_song=\(song.id) queue_count=\(queue.count) unique_song_count=\(uniqueSongCount)"
    )

    let queueItem = queueItemFactory.makeItem(for: song, client: client, forceRemote: forceRemote)
    let item = queueItem.item
    let isLocal = queueItem.isLocal
    player.insert(item, after: nil)

    playStartTime = Date()
    playStartSource = isLocal ? "local" : "remote"

    progressState.resetForNewSong(songId: song.id)
    observerState.resetForNewSong()

    MetricsLogger.shared.log("rebuild_queue_source song=\(song.id) source=\(isLocal ? "local" : "remote") force_remote=\(forceRemote)")

    updateNowPlayingInfo(client: client, elapsedTime: 0)

    // repeat-one behavior
    if let token = observerState.endObserver { NotificationCenter.default.removeObserver(token) }
    observerState.endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        let itemDuration = CMTimeGetSeconds(item.duration)
        let currentTime = CMTimeGetSeconds(item.currentTime())
        MetricsLogger.shared.log(
          "item_did_end mode=\(self.mode.rawValue) current_index=\(self.currentIndex) current_song=\(song.id) queue_count=\(self.queue.count) item_current=\(currentTime) item_duration=\(itemDuration)"
        )
        if self.mode == .repeatOne {
          MetricsLogger.shared.log("item_did_end_action repeat_one_restart song=\(song.id)")
          item.seek(to: .zero, completionHandler: nil)
          self.player.play()
          self.isPlaying = true
          self.updatePlaybackRate()
        } else {
          MetricsLogger.shared.log("item_did_end_action next song=\(song.id)")
          self.next(client: client)
        }
      }
    }

    if let token = observerState.stalledObserver { NotificationCenter.default.removeObserver(token) }
    observerState.stalledObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemPlaybackStalled,
      object: item,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        let itemDuration = CMTimeGetSeconds(item.duration)
        let currentTime = CMTimeGetSeconds(item.currentTime())
        MetricsLogger.shared.log(
          "item_stalled mode=\(self.mode.rawValue) current_index=\(self.currentIndex) current_song=\(song.id) item_current=\(currentTime) item_duration=\(itemDuration) time_control=\(self.player.timeControlStatus.rawValue) reason=\(self.player.reasonForWaitingToPlay?.rawValue ?? "nil")"
        )
        self.logPlaybackSnapshot(
          reason: "item_stalled",
          item: item,
          rawCurrentSeconds: currentTime,
          displayedCurrentSeconds: self.currentTime,
          duration: self.currentDuration
        )
      }
    }

    if let token = observerState.failedToEndObserver { NotificationCenter.default.removeObserver(token) }
    observerState.failedToEndObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] notification in
      guard let self else { return }
      Task { @MainActor in
        let itemDuration = CMTimeGetSeconds(item.duration)
        let currentTime = CMTimeGetSeconds(item.currentTime())
        let err = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError)?.localizedDescription ?? "unknown"
        MetricsLogger.shared.log(
          "item_failed_to_end mode=\(self.mode.rawValue) current_index=\(self.currentIndex) current_song=\(song.id) item_current=\(currentTime) item_duration=\(itemDuration) error=\(err)"
        )
        self.logPlaybackSnapshot(
          reason: "item_failed_to_end",
          item: item,
          rawCurrentSeconds: currentTime,
          displayedCurrentSeconds: self.currentTime,
          duration: self.currentDuration
        )
      }
    }

    if let token = observerState.timeJumpedObserver { NotificationCenter.default.removeObserver(token) }
    observerState.timeJumpedObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemTimeJumped,
      object: item,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        let raw = CMTimeGetSeconds(self.player.currentTime())
        MetricsLogger.shared.log(
          "item_time_jumped mode=\(self.mode.rawValue) current_index=\(self.currentIndex) current_song=\(song.id) raw_time=\(self.fmt5(raw))"
        )
        self.logPlaybackSnapshot(
          reason: "item_time_jumped",
          item: item,
          rawCurrentSeconds: raw,
          displayedCurrentSeconds: self.currentTime,
          duration: self.currentDuration
        )
      }
    }

    if let token = observerState.accessLogObserver { NotificationCenter.default.removeObserver(token) }
    observerState.accessLogObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemNewAccessLogEntry,
      object: item,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        let raw = CMTimeGetSeconds(self.player.currentTime())
        self.logPlaybackSnapshot(
          reason: "new_access_log_entry",
          item: item,
          rawCurrentSeconds: raw,
          displayedCurrentSeconds: self.currentTime,
          duration: self.currentDuration
        )
      }
    }

    // Monitor for failure status to help debug why nothing plays
    item.publisher(for: \.status)
      .sink { [weak self] status in
        guard let self else { return }
        MetricsLogger.shared.log(
          "item_status song=\(song.id) status=\(status.rawValue) mode=\(self.mode.rawValue) current_index=\(self.currentIndex) queue_count=\(self.queue.count)"
        )
        if status == .readyToPlay, let start = self.playStartTime {
          let durationMs = Int(Date().timeIntervalSince(start) * 1000)
          let source = self.playStartSource ?? "unknown"
          let itemDuration = CMTimeGetSeconds(item.duration)
          let metadataDuration = Double(self.current?.duration ?? 0)
          MetricsLogger.shared.log(
            "play_start_ready songId=\(song.id) source=\(source) duration_ms=\(durationMs) item_duration=\(itemDuration) metadata_duration=\(metadataDuration)"
          )
          self.playStartTime = nil
          self.playStartSource = nil
          self.updateNowPlayingInfo(client: client, elapsedTime: 0, itemDuration: item.duration)

          self.observerState.timeControlStatusCancellable = self.player.publisher(for: \.timeControlStatus)
            .sink { [weak self] status in
              guard let self else { return }
              let waitingReason = self.player.reasonForWaitingToPlay?.rawValue ?? "nil"
              let songId = self.current?.id ?? "nil"
              MetricsLogger.shared.log(
                "time_control_kvo status=\(status.rawValue) reason=\(waitingReason) current_song=\(songId) current_index=\(self.currentIndex)"
              )
            }

        }
        if status == .failed, let error = item.error {
          MetricsLogger.shared.log(
            "item_status_failed song=\(song.id) mode=\(self.mode.rawValue) current_index=\(self.currentIndex) error=\(error.localizedDescription)"
          )
          let failedCurrent = CMTimeGetSeconds(self.player.currentTime())
          self.logPlaybackSnapshot(
            reason: "item_status_failed",
            item: item,
            rawCurrentSeconds: failedCurrent,
            displayedCurrentSeconds: self.currentTime,
            duration: self.currentDuration
          )
          if isLocal {
            AudioCache.shared.invalidate(songId: song.id)
            self.rebuildQueue(client: client, forceRemote: true)
            self.startPlayback(client: client)
          }
          MetricsLogger.shared.log(
            "playback_item_error song=\(song.id) error=\(error.localizedDescription) details=\(String(describing: item.error))"
          )
        }
      }
      .store(in: &observerState.cancellables)

    attachTimeObserver(item: item)
  }
}

struct PlaybackObserverState {
  var cancellables = Set<AnyCancellable>()
  var timeControlStatusCancellable: AnyCancellable?
  var endObserver: Any?
  var stalledObserver: Any?
  var failedToEndObserver: Any?
  var timeJumpedObserver: Any?
  var accessLogObserver: Any?
  var timeObserver: Any?
  var lastLoggedTimeControlStatus: AVPlayer.TimeControlStatus?
  var lastLoggedProgressTick: Int?
  var lastSnapshotTick: Int?

  mutating func resetForNewSong() {
    timeControlStatusCancellable = nil
    lastLoggedTimeControlStatus = nil
    lastLoggedProgressTick = nil
    lastSnapshotTick = nil
  }

  mutating func clearObservers(using player: AVQueuePlayer) {
    if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    if let stalledObserver { NotificationCenter.default.removeObserver(stalledObserver) }
    if let failedToEndObserver { NotificationCenter.default.removeObserver(failedToEndObserver) }
    if let timeJumpedObserver { NotificationCenter.default.removeObserver(timeJumpedObserver) }
    if let accessLogObserver { NotificationCenter.default.removeObserver(accessLogObserver) }
    if let timeObserver { player.removeTimeObserver(timeObserver) }
  }
}

struct PlaybackProgressState {
  var monitoredSongId: String?
  var lastObservedProgressSeconds: Double?
  var lastObservedRawProgressSeconds: Double?
  var stagnantTicksNearEnd: Int = 0
  var didTriggerNearEndFallback: Bool = false
  var lastManualSeekAt: Date?
  var lastObservedSegmentsDownloadedDuration: Double?
  var lastObservedMediaRequestCount: Int?

  mutating func resetForNewSong(songId: String) {
    monitoredSongId = songId
    lastObservedProgressSeconds = nil
    lastObservedRawProgressSeconds = nil
    stagnantTicksNearEnd = 0
    didTriggerNearEndFallback = false
    lastManualSeekAt = nil
    lastObservedSegmentsDownloadedDuration = nil
    lastObservedMediaRequestCount = nil
  }
}
