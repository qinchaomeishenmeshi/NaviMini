import AVFoundation
import Foundation

struct PlaybackQueueItem {
  let item: AVPlayerItem
}

@MainActor
final class PlaybackQueueItemFactory {
  func makeItem(
    for song: Song,
    client: SubsonicClient
  ) -> PlaybackQueueItem {
    let url = client.streamURL(songId: song.id, format: "mp3", maxBitRate: 192)
    return PlaybackQueueItem(item: AVPlayerItem(url: url))
  }
}
