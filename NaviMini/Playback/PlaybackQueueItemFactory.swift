import AVFoundation
import Foundation

struct PlaybackQueueItem {
  let item: AVPlayerItem
  let isLocal: Bool
}

@MainActor
final class PlaybackQueueItemFactory {
  func makeItem(
    for song: Song,
    client: SubsonicClient,
    forceRemote: Bool
  ) -> PlaybackQueueItem {
    if !forceRemote, let localURL = AudioCache.shared.localURL(for: song.id) {
      return PlaybackQueueItem(item: AVPlayerItem(url: localURL), isLocal: true)
    }

    let url = client.streamURL(songId: song.id, format: "mp3", maxBitRate: 192)
    AudioCache.shared.cacheSong(url: url, songId: song.id)
    return PlaybackQueueItem(item: AVPlayerItem(url: url), isLocal: false)
  }
}
