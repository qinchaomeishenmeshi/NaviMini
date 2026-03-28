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
    let format: SubsonicClient.StreamFormat = song.shouldUseRawStream
      ? .raw
      : .mp3(maxBitRate: 192)
    let url = client.streamURL(songId: song.id, format: format)
    return PlaybackQueueItem(item: AVPlayerItem(url: url))
  }
}
