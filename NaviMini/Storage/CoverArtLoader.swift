import Foundation
import UIKit

enum CoverArtLoader {
  static func image(from url: URL) async -> UIImage? {
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      return UIImage(data: data)
    } catch {
      return nil
    }
  }
}
