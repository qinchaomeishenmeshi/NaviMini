import Foundation

final class CacheIndex {
  static let shared = CacheIndex()

  struct Entry: Codable {
    var size: Int
    var lastAccess: TimeInterval
    var relativePath: String
    var type: String
  }

  private struct IndexFile: Codable {
    var entries: [String: Entry]
  }

  private let ioQueue = DispatchQueue(label: "cache.index.io")
  private let maxDiskBytes: Int = 4 * 1024 * 1024 * 1024 // 4GB

  private var index = IndexFile(entries: [:])

  private var cacheRoot: URL? {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
      .appendingPathComponent("Cache", isDirectory: true)
  }

  private var indexURL: URL? {
    cacheRoot?.appendingPathComponent("index.json")
  }

  private init() {
    prepareRoot()
    loadIndex()
  }

  func entry(for key: String) -> Entry? {
    ioQueue.sync {
      index.entries[key]
    }
  }

  func recordAccess(key: String) {
    ioQueue.async {
      guard var entry = self.index.entries[key] else { return }
      entry.lastAccess = Date().timeIntervalSince1970
      self.index.entries[key] = entry
      self.persistIndex()
    }
  }

  func touch(key: String, type: String, relativePath: String, size: Int) {
    ioQueue.async {
      let entry = Entry(size: size, lastAccess: Date().timeIntervalSince1970, relativePath: relativePath, type: type)
      self.index.entries[key] = entry
      self.persistIndex()
      self.pruneIfNeeded()
    }
  }

  func remove(key: String) {
    ioQueue.async {
      self.index.entries.removeValue(forKey: key)
      self.persistIndex()
    }
  }

  func allEntries() -> [String: Entry] {
    ioQueue.sync {
      index.entries
    }
  }

  func cacheRootURL() -> URL? {
    cacheRoot
  }

  private func prepareRoot() {
    guard let root = cacheRoot else { return }
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  private func loadIndex() {
    guard let url = indexURL, let data = try? Data(contentsOf: url) else { return }
    if let decoded = try? JSONDecoder().decode(IndexFile.self, from: data) {
      index = decoded
    }
  }

  private func persistIndex() {
    guard let url = indexURL, let data = try? JSONEncoder().encode(index) else { return }
    try? data.write(to: url, options: [.atomic])
  }

  private func pruneIfNeeded() {
    var total = index.entries.values.reduce(0) { $0 + $1.size }
    guard total > maxDiskBytes else { return }

    let sorted = index.entries.sorted { $0.value.lastAccess < $1.value.lastAccess }
    for (key, entry) in sorted {
      guard total > maxDiskBytes else { break }
      if let root = cacheRoot {
        let fileURL = root.appendingPathComponent(entry.relativePath)
        try? FileManager.default.removeItem(at: fileURL)
      }
      print("[CacheIndex] pruned key=\(key) size=\(entry.size)")
      index.entries.removeValue(forKey: key)
      total -= entry.size
    }
    persistIndex()
  }
}
