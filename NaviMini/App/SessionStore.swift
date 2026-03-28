import Foundation

@MainActor
final class SessionStore: ObservableObject {
  static let shared = SessionStore()

  let baseURLString: String
  let username: String
  let password: String

  init() {
    baseURLString = "https://nd.cherishxn.eu.cc/rest"
    username = "qzx"
    password = "tYU921109@"

    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
      CoverCache.shared.healthCheck()
      AudioCache.shared.healthCheck()
    }
  }

  func makeClient() throws -> SubsonicClient {
    guard let url = URL(string: baseURLString) else {
      throw NSError(domain: "Config", code: 1, userInfo: [NSLocalizedDescriptionKey: "Base URL 不合法"])
    }
    return SubsonicClient(baseURL: url, username: username, password: password)
  }
}
