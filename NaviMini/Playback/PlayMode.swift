import Foundation

enum PlayMode: String, CaseIterable, Identifiable {
  case order
  case shuffle
  case repeatOne

  var id: String { rawValue }

  var title: String {
    switch self {
    case .order: return "顺序"
    case .shuffle: return "随机"
    case .repeatOne: return "单曲循环"
    }
  }
}
