import XCTest
@testable import NaviMini

final class SubsonicModelsTests: XCTestCase {
  func testSongDTOMapsSuffixToSourceFormat() {
    let dto = SongDTO(
      id: "song-1",
      title: "Track",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil,
      suffix: "FLAC",
      contentType: nil
    )

    XCTAssertEqual(dto.toSong().sourceFormat, "flac")
  }

  func testSongDTOMapsContentTypeToSourceFormatWhenSuffixMissing() {
    let dto = SongDTO(
      id: "song-2",
      title: "Track",
      artist: "Artist",
      album: "Album",
      duration: 180,
      coverArt: nil,
      suffix: nil,
      contentType: "audio/flac"
    )

    XCTAssertEqual(dto.toSong().sourceFormat, "flac")
  }
}
