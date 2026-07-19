import Foundation

protocol SongLibraryFetching {
  func searchAllSongs(songCount: Int, songOffset: Int) async throws -> [Song]
}

extension SubsonicClient: SongLibraryFetching {}
