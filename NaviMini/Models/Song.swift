import Foundation

struct Song: Identifiable, Codable, Equatable {
  let id: String
  let title: String
  let artist: String
  let album: String
  let duration: Int?
  let coverArt: String?
  let sourceFormat: String?

  init(
    id: String,
    title: String,
    artist: String,
    album: String,
    duration: Int?,
    coverArt: String?,
    sourceFormat: String? = nil
  ) {
    self.id = id
    self.title = title
    self.artist = artist
    self.album = album
    self.duration = duration
    self.coverArt = coverArt
    self.sourceFormat = sourceFormat
  }

  var shouldUseRawStream: Bool {
    sourceFormat == "flac"
  }

  var cacheFileExtensionHint: String? {
    guard shouldUseRawStream else { return nil }
    return sourceFormat
  }

  var sourceFormatLabel: String? {
    guard sourceFormat == "flac" else { return nil }
    return "FLAC"
  }

  var nowPlayingSourceFormatLabel: String? {
    sourceFormat?.uppercased()
  }
}
