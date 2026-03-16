import Foundation

@MainActor
final class SessionStore: ObservableObject {
  static let shared = SessionStore()

  @Published var baseURLString: String
  @Published var username: String
  @Published var password: String
  @Published var isLoggedIn: Bool

  let cache = SongsCache()

  private let settings = AppSettings()
  private let keychain = KeychainStore()

  init() {
    let base = settings.baseURLString
    let user = settings.username
    let pass = keychain.load(account: "password") ?? ""
    let loggedIn = !user.isEmpty && !pass.isEmpty

    self.baseURLString = base
    self.username = user
    self.password = pass
    self.isLoggedIn = loggedIn

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

  func persist() {
    settings.baseURLString = baseURLString
    settings.username = username
    try? keychain.save(password, account: "password")
  }

  func logout() {
    isLoggedIn = false
    password = ""
    keychain.delete(account: "password")
  }
}
