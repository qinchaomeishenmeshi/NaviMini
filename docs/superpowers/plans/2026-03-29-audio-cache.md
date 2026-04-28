# Audio Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保持首次在线播放不变的前提下，为 NaviMini 增加整首歌曲后台缓存，并在后续播放时优先命中本地文件。

**Architecture:** 新增独立缓存层，拆分为缓存存储与下载两个职责。`PlaybackQueueItemFactory` 只负责选择本地或远端播放源，并在未命中缓存时触发后台整首下载，不把下载与文件管理耦合进 `PlaybackController`。

**Tech Stack:** Swift, Foundation, AVFoundation, URLSession, XCTest, Xcodebuild

---

### Task 1: 建立缓存键与文件存储层

**Files:**
- Create: `NaviMini/Storage/AudioCacheStore.swift`
- Modify: `NaviMini.xcodeproj/project.pbxproj`
- Test: `NaviMiniTests/AudioCacheStoreTests.swift`

- [ ] **Step 1: 写失败测试，锁定缓存键和缓存命中规则**

```swift
func testCacheKeyIncludesSongIdAndFormat() { ... }
func testCompleteCacheExistsWhenFileIsReadableAndNonEmpty() { ... }
func testBrokenCacheIsRemoved() { ... }
```

- [ ] **Step 2: 运行测试确认失败**

Run:
```bash
xcodebuild test -project /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj -scheme NaviMini -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:NaviMiniTests/AudioCacheStoreTests
```

Expected: FAIL，提示 `AudioCacheStore` 不存在或行为不匹配。

- [ ] **Step 3: 写最小实现**

实现 `AudioCacheStore`：

```swift
struct AudioCacheKey: Hashable {
  let songId: String
  let formatKey: String
}

final class AudioCacheStore {
  func fileURL(for key: AudioCacheKey) -> URL
  func cachedFileURLIfComplete(for key: AudioCacheKey) -> URL?
  func removeCache(for key: AudioCacheKey)
}
```

- [ ] **Step 4: 运行测试确认通过**

Run:
```bash
xcodebuild test -project /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj -scheme NaviMini -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:NaviMiniTests/AudioCacheStoreTests
```

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add /Users/cherishxn/workspace/2026/NaviMini/NaviMini/Storage/AudioCacheStore.swift /Users/cherishxn/workspace/2026/NaviMini/NaviMiniTests/AudioCacheStoreTests.swift /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj/project.pbxproj
git commit -m "feat: add audio cache store"
```

### Task 2: 建立后台整首下载器

**Files:**
- Create: `NaviMini/Storage/AudioCacheDownloader.swift`
- Modify: `NaviMini.xcodeproj/project.pbxproj`
- Test: `NaviMiniTests/AudioCacheDownloaderTests.swift`

- [ ] **Step 1: 写失败测试，锁定下载触发与去重语义**

```swift
func testDownloaderStartsSingleRequestPerCacheKey() async { ... }
func testDownloaderPersistsCompletedDownloadAtomically() async { ... }
```

- [ ] **Step 2: 运行测试确认失败**

Run:
```bash
xcodebuild test -project /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj -scheme NaviMini -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:NaviMiniTests/AudioCacheDownloaderTests
```

Expected: FAIL，提示 `AudioCacheDownloader` 不存在。

- [ ] **Step 3: 写最小实现**

实现 `AudioCacheDownloader`：

```swift
final class AudioCacheDownloader {
  func ensureCached(
    remoteURL: URL,
    cacheKey: AudioCacheKey,
    store: AudioCacheStore
  )
}
```

要求：

- 同一 `cacheKey` 正在下载时不重复发起
- 下载完成后写入临时文件再原子移动
- 失败只记录日志，不抛到播放主链路

- [ ] **Step 4: 运行测试确认通过**

Run:
```bash
xcodebuild test -project /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj -scheme NaviMini -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:NaviMiniTests/AudioCacheDownloaderTests
```

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add /Users/cherishxn/workspace/2026/NaviMini/NaviMini/Storage/AudioCacheDownloader.swift /Users/cherishxn/workspace/2026/NaviMini/NaviMiniTests/AudioCacheDownloaderTests.swift /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj/project.pbxproj
git commit -m "feat: add audio cache downloader"
```

### Task 3: 扩展 `SubsonicClient.StreamFormat` 生成稳定缓存格式键

**Files:**
- Modify: `NaviMini/Subsonic/SubsonicClient.swift`
- Test: `NaviMiniTests/AudioCacheStoreTests.swift`

- [ ] **Step 1: 写失败测试，锁定不同流格式的缓存键**

```swift
func testFormatKeyDistinguishesRawMp3AndFlac() { ... }
```

- [ ] **Step 2: 运行测试确认失败**

Run:
```bash
xcodebuild test -project /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj -scheme NaviMini -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:NaviMiniTests/AudioCacheStoreTests
```

Expected: FAIL，格式键无法区分流格式。

- [ ] **Step 3: 写最小实现**

在 `SubsonicClient.StreamFormat` 增加：

```swift
var cacheKey: String { ... }
```

- [ ] **Step 4: 运行相关测试确认通过**

Run:
```bash
xcodebuild test -project /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj -scheme NaviMini -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:NaviMiniTests/AudioCacheStoreTests
```

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add /Users/cherishxn/workspace/2026/NaviMini/NaviMini/Subsonic/SubsonicClient.swift /Users/cherishxn/workspace/2026/NaviMini/NaviMiniTests/AudioCacheStoreTests.swift
git commit -m "feat: add audio cache format keys"
```

### Task 4: 让播放队列工厂支持缓存命中与后台下载

**Files:**
- Modify: `NaviMini/Playback/PlaybackQueueItemFactory.swift`
- Modify: `NaviMini/Playback/PlaybackController.swift`
- Test: `NaviMiniTests/PlaybackQueueItemFactoryTests.swift`

- [ ] **Step 1: 写失败测试，锁定命中缓存与未命中行为**

```swift
func testMakeItemUsesCachedFileWhenCompleteCacheExists() { ... }
func testMakeItemUsesRemoteURLAndStartsBackgroundCachingWhenCacheMisses() { ... }
func testMakeItemDeletesBrokenCacheAndFallsBackToRemote() { ... }
```

- [ ] **Step 2: 运行测试确认失败**

Run:
```bash
xcodebuild test -project /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj -scheme NaviMini -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:NaviMiniTests/PlaybackQueueItemFactoryTests
```

Expected: FAIL，当前工厂始终返回远端 URL。

- [ ] **Step 3: 写最小实现**

调整 `PlaybackQueueItemFactory`：

- 注入 `AudioCacheStore`
- 注入 `AudioCacheDownloader`
- 优先返回本地文件 URL
- 缓存未命中时返回远端 URL，并触发后台下载

必要时在 `PlaybackController` 内集中持有共享缓存依赖，避免在视图层拼装。

- [ ] **Step 4: 运行测试确认通过**

Run:
```bash
xcodebuild test -project /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj -scheme NaviMini -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:NaviMiniTests/PlaybackQueueItemFactoryTests
```

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add /Users/cherishxn/workspace/2026/NaviMini/NaviMini/Playback/PlaybackQueueItemFactory.swift /Users/cherishxn/workspace/2026/NaviMini/NaviMini/Playback/PlaybackController.swift /Users/cherishxn/workspace/2026/NaviMini/NaviMiniTests/PlaybackQueueItemFactoryTests.swift
git commit -m "feat: prefer cached audio files for playback"
```

### Task 5: 扩展日志与最小回归验证

**Files:**
- Modify: `NaviMini/Storage/MetricsLogger.swift`
- Modify: `NaviMini/Playback/PlaybackController.swift`
- Test: `NaviMiniTests/AudioCacheDownloaderTests.swift`

- [ ] **Step 1: 写失败测试，锁定缓存命中与下载失败日志行为**

```swift
func testLogsCacheHitAndMissEvents() { ... }
```

- [ ] **Step 2: 运行测试确认失败**

Run:
```bash
xcodebuild test -project /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj -scheme NaviMini -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:NaviMiniTests/AudioCacheDownloaderTests
```

Expected: FAIL，缺少缓存相关日志输出。

- [ ] **Step 3: 写最小实现**

增加最少日志：

- `audio_cache_hit`
- `audio_cache_miss`
- `audio_cache_download_started`
- `audio_cache_download_finished`
- `audio_cache_download_failed`

- [ ] **Step 4: 运行完整测试集确认通过**

Run:
```bash
xcodebuild test -project /Users/cherishxn/workspace/2026/NaviMini/NaviMini.xcodeproj -scheme NaviMini -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'
```

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add /Users/cherishxn/workspace/2026/NaviMini/NaviMini/Storage/MetricsLogger.swift /Users/cherishxn/workspace/2026/NaviMini/NaviMini/Playback/PlaybackController.swift /Users/cherishxn/workspace/2026/NaviMini/NaviMiniTests/AudioCacheDownloaderTests.swift
git commit -m "feat: add audio cache metrics"
```
