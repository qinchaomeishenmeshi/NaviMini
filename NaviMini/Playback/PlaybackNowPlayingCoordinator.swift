import AVFoundation
import Foundation
import MediaPlayer

struct PlaybackNowPlayingCoordinator {
  private static let sourceFormatInfoKey = "com.cherishxn.navimini.sourceFormat"

  func makeNowPlayingInfo(
    song: Song,
    isPlaying: Bool,
    elapsedTime: Double = 0,
    itemDuration: CMTime? = nil
  ) -> [String: Any] {
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: song.title,
      MPMediaItemPropertyArtist: song.artist,
      MPMediaItemPropertyAlbumTitle: song.album,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
      MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
    ]

    if let sourceFormatLabel = song.nowPlayingSourceFormatLabel {
      info[MPMediaItemPropertyComments] = sourceFormatLabel
      info[Self.sourceFormatInfoKey] = sourceFormatLabel
    }

    let itemDurationSeconds = itemDuration.map(CMTimeGetSeconds)
    if let duration = PlaybackQueueLogic.resolvedPlaybackDuration(
      metadataDuration: song.duration,
      itemDurationSeconds: itemDurationSeconds
    ) {
      info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: duration)
    }

    return info
  }

  func update(
    song: Song?,
    isPlaying: Bool,
    client: SubsonicClient,
    elapsedTime: Double = 0,
    itemDuration: CMTime? = nil
  ) {
    guard let song else { return }
    let info = makeNowPlayingInfo(
      song: song,
      isPlaying: isPlaying,
      elapsedTime: elapsedTime,
      itemDuration: itemDuration
    )
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info

    if let artId = song.coverArt {
      let url = client.coverArtURL(coverArtId: artId)
      Task {
        if let image = await CoverArtLoader.image(from: url) {
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
