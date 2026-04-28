import AVFoundation
import Foundation

enum PlaybackSource: Equatable {
  case remote
  case localCache
}

struct PlaybackQueueItem {
  let item: AVPlayerItem
  let source: PlaybackSource
}

@MainActor
final class PlaybackQueueItemFactory {
  private let cacheStore: AudioCacheStore
  private let cacheDownloader: AudioCacheDownloading

  convenience init() {
    let cacheStore = AudioCacheStore()
    self.init(
      cacheStore: cacheStore,
      cacheDownloader: AudioCacheDownloader(store: cacheStore)
    )
  }

  init(cacheStore: AudioCacheStore, cacheDownloader: AudioCacheDownloading) {
    self.cacheStore = cacheStore
    self.cacheDownloader = cacheDownloader
  }

  func makeItem(
    for song: Song,
    client: SubsonicClient
  ) -> PlaybackQueueItem {
    let format: SubsonicClient.StreamFormat = song.shouldUseRawStream
      ? .raw
      : .mp3(maxBitRate: 192)
    let remoteURL = client.streamURL(songId: song.id, format: format)
    let cacheKey = AudioCacheKey(
      songId: song.id,
      formatKey: format.cacheKey,
      originalFileExtension: song.cacheFileExtensionHint
    )

    if let cachedURL = cacheStore.cachedFileURLIfComplete(for: cacheKey) {
      MetricsLogger.shared.log("audio_cache_hit song=\(song.id) format=\(format.cacheKey)")
      return PlaybackQueueItem(item: AVPlayerItem(url: cachedURL), source: .localCache)
    }

    MetricsLogger.shared.log("audio_cache_miss song=\(song.id) format=\(format.cacheKey)")
    cacheDownloader.ensureCached(remoteURL: remoteURL, cacheKey: cacheKey)
    return PlaybackQueueItem(item: AVPlayerItem(url: remoteURL), source: .remote)
  }
}
