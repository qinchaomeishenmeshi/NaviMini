import Foundation

final class AppSettings {
  private let defaults = UserDefaults.standard

  private enum Keys {
    static let baseURL = "baseURL"
    static let username = "username"
  }

  var baseURLString: String {
    get { defaults.string(forKey: Keys.baseURL) ?? "https://your-domain.example.com/rest" }
    set { defaults.set(newValue, forKey: Keys.baseURL) }
  }

  var username: String {
    get { defaults.string(forKey: Keys.username) ?? "" }
    set { defaults.set(newValue, forKey: Keys.username) }
  }
}
