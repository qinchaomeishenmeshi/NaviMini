import Foundation

struct Song: Identifiable, Codable, Equatable {
  let id: String
  let title: String
  let artist: String
  let album: String
  let duration: Int?
  let coverArt: String?
}
