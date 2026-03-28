import AVFoundation
import MediaPlayer
import XCTest
@testable import NaviMini

final class PlaybackNowPlayingCoordinatorTests: XCTestCase {
  func testSongSourceFormatLabelOnlyShowsFlac() {
    let flacSong = Song(
      id: "song-1",
      title: "Lossless",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil,
      sourceFormat: "flac"
    )

    let mp3Song = Song(
      id: "song-2",
      title: "Compressed",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil,
      sourceFormat: "mp3"
    )

    XCTAssertEqual(flacSong.sourceFormatLabel, "FLAC")
    XCTAssertNil(mp3Song.sourceFormatLabel)
  }

  func testMakeNowPlayingInfoIncludesSourceFormat() {
    let coordinator = PlaybackNowPlayingCoordinator()
    let song = Song(
      id: "song-1",
      title: "Lossless",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil,
      sourceFormat: "flac"
    )

    let info = coordinator.makeNowPlayingInfo(song: song, isPlaying: true, elapsedTime: 12, itemDuration: nil)

    XCTAssertEqual(info[MPMediaItemPropertyComments] as? String, "FLAC")
    XCTAssertEqual(info["com.cherishxn.navimini.sourceFormat"] as? String, "FLAC")
    XCTAssertEqual(info[MPMediaItemPropertyTitle] as? String, "Lossless")
    XCTAssertEqual(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1.0)
  }
}
