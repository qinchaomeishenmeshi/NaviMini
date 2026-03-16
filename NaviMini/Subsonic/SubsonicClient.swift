import Foundation

struct SubsonicClient {
  let baseURL: URL
  let username: String
  let password: String

  private let apiVersion = "1.16.1"
  private let clientName = "NaviMini"

  private func endpoint(_ name: String) -> URL {
    // baseURL should be .../rest
    baseURL.appendingPathComponent(name)
  }

  private func requestURL(_ name: String, extra: [URLQueryItem]) -> URL {
    var c = URLComponents(url: endpoint(name), resolvingAgainstBaseURL: false)!

    var items: [URLQueryItem] = [
      .init(name: "u", value: username),
      .init(name: "p", value: password),
      .init(name: "v", value: apiVersion),
      .init(name: "c", value: clientName),
      .init(name: "f", value: "json"),
    ]
    items.append(contentsOf: extra)
    c.queryItems = items
    return c.url!
  }

  func ping() async throws -> Bool {
    let url = requestURL("ping", extra: [])
    let (data, _) = try await URLSession.shared.data(from: url)

    let env = try JSONDecoder().decode(SubsonicEnvelope<EmptyPayload>.self, from: data)
    return env.response.status == "ok"
  }

  func searchAllSongs(songCount: Int = 50, songOffset: Int = 0) async throws -> [Song] {
    let url = requestURL(
      "search3",
      extra: [
        .init(name: "query", value: ""),
        .init(name: "songCount", value: String(songCount)),
        .init(name: "songOffset", value: String(songOffset)),
        .init(name: "albumCount", value: "0"),
        .init(name: "artistCount", value: "0"),
      ]
    )

    let (data, _) = try await URLSession.shared.data(from: url)
    let env = try JSONDecoder().decode(SubsonicEnvelope<SearchResult3>.self, from: data)

    guard env.response.status == "ok" else {
      let msg = env.response.error?.message ?? "unknown error"
      throw NSError(domain: "Subsonic", code: env.response.error?.code ?? -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    let dtos = env.response.data?.song ?? []
    return dtos.map { $0.toSong() }
  }

  func streamURL(songId: String, format: String = "mp3", maxBitRate: Int = 192) -> URL {
    requestURL("stream.view", extra: [
      .init(name: "id", value: songId),
      .init(name: "format", value: format),
      .init(name: "maxBitRate", value: String(maxBitRate)),
    ])
  }

  func coverArtURL(coverArtId: String) -> URL {
    requestURL("getCoverArt.view", extra: [
      .init(name: "id", value: coverArtId)
    ])
  }
}

private struct EmptyPayload: Decodable {}
