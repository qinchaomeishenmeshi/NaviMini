import Foundation

final class SongsCache {
  private let fileName = "songs.json"

  private var fileURL: URL? {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
  }

  func load() -> [Song] {
    guard let url = fileURL else { return [] }
    guard let data = try? Data(contentsOf: url) else { return [] }
    return (try? JSONDecoder().decode([Song].self, from: data)) ?? []
  }

  func save(_ songs: [Song]) {
    guard let url = fileURL else { return }
    guard let data = try? JSONEncoder().encode(songs) else { return }
    try? data.write(to: url, options: [.atomic])
  }
}
