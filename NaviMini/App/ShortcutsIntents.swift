import AppIntents

struct PlayPauseIntent: AppIntent {
  static var title: LocalizedStringResource = "播放/暂停"
  static var description = IntentDescription("切换播放或暂停")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    PlaybackController.shared.togglePlayPause()
    return .result()
  }
}

struct ResumePlaybackIntent: AppIntent {
  static var title: LocalizedStringResource = "继续播放"
  static var description = IntentDescription("继续当前播放")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    PlaybackController.shared.resumePlayback()
    return .result()
  }
}

enum ShortcutError: LocalizedError {
  case needsLogin

  var errorDescription: String? {
    switch self {
    case .needsLogin:
      return "请先登录并刷新列表"
    }
  }
}

struct ShuffleCurrentListIntent: AppIntent {
  static var title: LocalizedStringResource = "随机播放（当前列表）"
  static var description = IntentDescription("随机播放当前列表歌曲")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    do {
      let client = try SessionStore.shared.makeClient()
      PlaybackController.shared.shuffleCurrentList(client: client)
      return .result()
    } catch {
      throw ShortcutError.needsLogin
    }
  }
}

struct StartPlaybackIntent: AppIntent {
  static var title: LocalizedStringResource = "开始播放"
  static var description = IntentDescription("开始顺序播放当前列表")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    let client = try SessionStore.shared.makeClient()
    try await PlaybackController.shared.startFirstIfNeeded(client: client)
    return .result()
  }
}

struct NextTrackIntent: AppIntent {
  static var title: LocalizedStringResource = "下一首"
  static var description = IntentDescription("播放下一首")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    let client = try SessionStore.shared.makeClient()
    PlaybackController.shared.next(client: client)
    return .result()
  }
}

struct PreviousTrackIntent: AppIntent {
  static var title: LocalizedStringResource = "上一首"
  static var description = IntentDescription("播放上一首")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    let client = try SessionStore.shared.makeClient()
    PlaybackController.shared.prev(client: client)
    return .result()
  }
}

struct NaviMiniShortcutsProvider: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: PlayPauseIntent(),
      phrases: [
        "播放或暂停 \(.applicationName)",
        "切换播放 \(.applicationName)",
        "\(.applicationName) 播放暂停",
        "bob 播放暂停 \(.applicationName)",
        "bob 播放或暂停 \(.applicationName)"
      ],
      shortTitle: "播放/暂停",
      systemImageName: "playpause"
    )
    AppShortcut(
      intent: ResumePlaybackIntent(),
      phrases: [
        "继续播放 \(.applicationName)",
        "恢复播放 \(.applicationName)",
        "bob 继续播放 \(.applicationName)",
        "bob 恢复播放 \(.applicationName)"
      ],
      shortTitle: "继续播放",
      systemImageName: "play.fill"
    )
    AppShortcut(
      intent: StartPlaybackIntent(),
      phrases: [
        "开始播放 \(.applicationName)",
        "\(.applicationName) 播放",
        "bob 播放歌曲 \(.applicationName)",
        "bob 开始播放 \(.applicationName)"
      ],
      shortTitle: "开始播放",
      systemImageName: "play.circle"
    )
    AppShortcut(
      intent: NextTrackIntent(),
      phrases: [
        "下一首 \(.applicationName)",
        "切换下一首 \(.applicationName)",
        "bob 下一首 \(.applicationName)",
        "bob 切换下一首 \(.applicationName)"
      ],
      shortTitle: "下一首",
      systemImageName: "forward.fill"
    )
    AppShortcut(
      intent: PreviousTrackIntent(),
      phrases: [
        "上一首 \(.applicationName)",
        "切换上一首 \(.applicationName)",
        "bob 上一首 \(.applicationName)",
        "bob 切换上一首 \(.applicationName)"
      ],
      shortTitle: "上一首",
      systemImageName: "backward.fill"
    )
    AppShortcut(
      intent: ShuffleCurrentListIntent(),
      phrases: [
        "随机播放 \(.applicationName)",
        "随机播放当前列表 \(.applicationName)",
        "bob 随机播放 \(.applicationName)",
        "bob 随机播放当前列表 \(.applicationName)"
      ],
      shortTitle: "随机播放",
      systemImageName: "shuffle"
    )
  }
}
