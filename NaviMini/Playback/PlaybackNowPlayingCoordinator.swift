import AVFoundation
import Foundation
import MediaPlayer

struct PlaybackNowPlayingCoordinator {
  func update(
    song: Song?,
    isPlaying: Bool,
    client: SubsonicClient,
    elapsedTime: Double = 0,
    itemDuration: CMTime? = nil
  ) {
    guard let song else { return }

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

  func updatePlaybackRate(isPlaying: Bool) {
    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
    info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }
}
