import Foundation

final class MetricsLogger {
  static let shared = MetricsLogger()

  private let ioQueue = DispatchQueue(label: "metrics.logger")

  private var logURL: URL? {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
      .appendingPathComponent("metrics.log")
  }

  func log(_ message: String) {
    let line = "\(timestamp()) \(message)\n"
    print("[Metrics] \(message)")
    ioQueue.async {
      guard let url = self.logURL else { return }
      if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: url.path) {
          if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
          }
        } else {
          try? data.write(to: url, options: [.atomic])
        }
      }
    }
  }

  private func timestamp() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
  }
}
