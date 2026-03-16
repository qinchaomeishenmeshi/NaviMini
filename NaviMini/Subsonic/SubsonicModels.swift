import Foundation

// Subsonic JSON uses a top-level key: "subsonic-response"
struct SubsonicEnvelope<T: Decodable>: Decodable {
  let response: SubsonicResponse<T>

  enum CodingKeys: String, CodingKey {
    case response = "subsonic-response"
  }
}

struct SubsonicResponse<T: Decodable>: Decodable {
  let status: String
  let version: String?
  let data: T?
  let error: SubsonicError?

  struct SubsonicError: Decodable {
    let code: Int
    let message: String
  }

  // We decode *one* payload field into `data` depending on endpoint.
  // For ping: no payload field.
  // For search3: `searchResult3`.
  enum CodingKeys: String, CodingKey {
    case status
    case version
    case error
    case searchResult3
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    status = (try? c.decode(String.self, forKey: .status)) ?? "failed"
    version = try? c.decode(String.self, forKey: .version)
    error = try? c.decode(SubsonicError.self, forKey: .error)

    if let v = try? c.decode(T.self, forKey: .searchResult3) {
      data = v
    } else {
      data = nil
    }
  }
}

struct SearchResult3: Decodable {
  let song: [SongDTO]?
}

struct SongDTO: Decodable {
  let id: String
  let title: String?
  let artist: String?
  let album: String?
  let duration: Int?
  let coverArt: String?
}

extension SongDTO {
  func toSong() -> Song {
    Song(
      id: id,
      title: title ?? "",
      artist: artist ?? "",
      album: album ?? "",
      duration: duration,
      coverArt: coverArt
    )
  }
}
