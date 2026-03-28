import Foundation
import UIKit

final class CoverCache {
  static let shared = CoverCache()

  func healthCheck() {
    let entries = CacheIndex.shared.allEntries()
    guard let root = CacheIndex.shared.cacheRootURL() else { return }
    var scanned = 0
    var removed = 0

    for (key, entry) in entries where entry.type == "cover" {
      scanned += 1
      let url = root.appendingPathComponent(entry.relativePath)
      let exists = FileManager.default.fileExists(atPath: url.path)
      if !exists || entry.size <= 0 {
        try? FileManager.default.removeItem(at: url)
        CacheIndex.shared.remove(key: key)
        removed += 1
      }
    }

    MetricsLogger.shared.log("cache_health cover scanned=\(scanned) removed=\(removed)")
  }

  private let ioQueue = DispatchQueue(label: "cover.cache.io")
  private let memoryCache = NSCache<NSString, UIImage>()

  private var cacheRoot: URL? {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
      .appendingPathComponent("Cache", isDirectory: true)
  }

  private var coversDir: URL? {
    cacheRoot?.appendingPathComponent("covers", isDirectory: true)
  }

  private init() {
    memoryCache.totalCostLimit = 128 * 1024 * 1024 // 128MB
    prepareDirs()
  }

  func image(for coverArtId: String, url: URL) async -> UIImage? {
    let key = cacheKey(for: coverArtId)

    if let cached = memoryCache.object(forKey: coverArtId as NSString) {
      CacheIndex.shared.recordAccess(key: key)
      return cached
    }

    if let diskImage = await loadFromDisk(coverArtId) {
      memoryCache.setObject(diskImage, forKey: coverArtId as NSString, cost: diskImage.cost)
      return diskImage
    }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      if let image = UIImage(data: data) {
        memoryCache.setObject(image, forKey: coverArtId as NSString, cost: image.cost)
        await saveToDisk(coverArtId, data: data)
        return image
      }
    } catch {
      // ignore
    }

    return nil
  }

  private func cacheKey(for id: String) -> String {
    "cover:\(id)"
  }

  private func relativePath(for id: String) -> String {
    "covers/\(id).dat"
  }

  private func prepareDirs() {
    guard let root = cacheRoot, let covers = coversDir else { return }
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(at: covers, withIntermediateDirectories: true)
  }

  private func fileURL(for key: String) -> URL? {
    coversDir?.appendingPathComponent(key).appendingPathExtension("dat")
  }

  private func loadFromDisk(_ key: String) async -> UIImage? {
    let url = fileURL(for: key)
    let cacheKey = cacheKey(for: key)
    let relativePath = relativePath(for: key)
    return await withCheckedContinuation { (cont: CheckedContinuation<UIImage?, Never>) in
      ioQueue.async {
        guard let url,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
          cont.resume(returning: nil)
          return
        }

        CacheIndex.shared.touch(
          key: cacheKey,
          type: "cover",
          relativePath: relativePath,
          size: data.count
        )
        cont.resume(returning: image)
      }
    }
  }

  private func saveToDisk(_ key: String, data: Data) async {
    let url = fileURL(for: key)
    let cacheKey = cacheKey(for: key)
    let relativePath = relativePath(for: key)
    let size = data.count
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
      ioQueue.async {
        guard let url else {
          cont.resume()
          return
        }
        try? data.write(to: url, options: [.atomic])
        CacheIndex.shared.touch(
          key: cacheKey,
          type: "cover",
          relativePath: relativePath,
          size: size
        )
        cont.resume()
      }
    }
  }
}

private extension UIImage {
  var cost: Int {
    guard let cgImage = self.cgImage else { return 1 }
    return cgImage.bytesPerRow * cgImage.height
  }
}
