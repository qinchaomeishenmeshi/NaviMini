---
name: NaviMini
description: 个人 Navidrome 库的轻量 iOS 播放器——清晰、直接、实用
colors:
  accent: "#007AFF"
  accent-soft: "#007AFF1F"
  accent-muted: "#007AFFE6"
  label: "#000000"
  label-secondary: "#3C3C4399"
  surface: "#FFFFFF"
  surface-secondary: "#F2F2F7"
  placeholder: "#8E8E9333"
  error: "#FF3B30"
  on-accent: "#FFFFFF"
  progress-track: "#0000001F"
  progress-buffered: "#0000002E"
  knob-shadow: "#0000001F"
typography:
  title2:
    fontFamily: "SF Pro, system-ui, -apple-system, sans-serif"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.27
  body:
    fontFamily: "SF Pro, system-ui, -apple-system, sans-serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.29
  body-emphasis:
    fontFamily: "SF Pro, system-ui, -apple-system, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.29
  subheadline:
    fontFamily: "SF Pro, system-ui, -apple-system, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.33
  footnote:
    fontFamily: "SF Pro, system-ui, -apple-system, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.38
  caption:
    fontFamily: "SF Pro, system-ui, -apple-system, sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.33
  caption2:
    fontFamily: "SF Pro, system-ui, -apple-system, sans-serif"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: 1.27
  time-mono:
    fontFamily: "SF Pro, ui-monospace, Menlo, monospace"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.33
rounded:
  sm: "8px"
  md: "10px"
  cover: "16px"
  cover-hero: "24px"
  full: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  control-gap: "40px"
  row-y: "9px"
components:
  button-play:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.full}"
    padding: "16px"
    size: "76px"
  button-transport:
    textColor: "{colors.label}"
    typography: "{typography.title2}"
  button-toolbar:
    backgroundColor: "{colors.accent-soft}"
    textColor: "{colors.accent}"
    rounded: "{rounded.full}"
    padding: "6px 10px"
    typography: "{typography.subheadline}"
  list-row-current:
    backgroundColor: "{colors.accent-soft}"
  badge-format:
    backgroundColor: "{colors.placeholder}"
    textColor: "{colors.label-secondary}"
    rounded: "{rounded.full}"
    padding: "1px 6px"
    typography: "{typography.caption2}"
  badge-local:
    backgroundColor: "{colors.accent-soft}"
    textColor: "{colors.accent-muted}"
    rounded: "{rounded.full}"
    padding: "1px 6px"
    typography: "{typography.caption2}"
  cover-art:
    backgroundColor: "{colors.placeholder}"
    rounded: "{rounded.cover}"
    width: "260px"
    height: "260px"
  progress-bar:
    backgroundColor: "{colors.progress-track}"
    rounded: "{rounded.full}"
    height: "6px"
---

# Design System: NaviMini

## Overview

**Creative North Star: "The Clear Control Deck"**

NaviMini 的界面像一块清楚、可触达的控制台：歌曲列表是目录，播放页是运输控件，系统媒体栏是延伸。视觉服务「点歌 → 听歌 → 控歌」这条路径，不卖气氛，不堆品牌秀。

密度适中、跟 iOS HIG。San Francisco 系统文字样式、系统 tint、inset List、分段控件与圆形主播放键构成默认词汇。实现上优先语义色（`Color.accentColor`、`primary`、`secondary`、`red`），让 Light / Dark Mode 与对比度设置自动跟上；下文 hex 是 Light Mode 下的可机读近似，不是第二套硬编码调色板。

系统明确拒绝：花哨流媒体感（强品牌色、大卡片墙、营销感）、信息过载的库管理工具感（控件密、设置深）、以及过度拟物 / 炫技动效（玻璃、光晕、夸张转场）。

**Key Characteristics:**
- 单一 accent，只服务交互与当前状态
- 系统字体与文字样式，无独立品牌字
- 列表直白、播放控件 decisively 居中
- 阴影极少，且只出现在可拖动控件上
- 错误用系统红直接暴露，不做装饰性兜底

## Colors

System Signal Blue + Quiet Labels：一条系统信号蓝驱动交互，文字与表面保持安静中性。

### Primary
- **System Signal Blue** (`#007AFF` → `{colors.accent}`): 主 tint。用于播放键、进度填充、当前曲高亮、本地缓存徽章、「正在播放」入口。实现用 `Color.accentColor`，勿再引入第二套品牌蓝。

### Neutral
- **Quiet Label** (`#000000` → `{colors.label}`): 主文案；实现用 `Color.primary` / `.label`。
- **Quiet Secondary** (`#3C3C4399` → `{colors.label-secondary}`): 艺人、专辑、次要时间；实现用 `Color.secondary`。
- **Surface** (`#FFFFFF` → `{colors.surface}`): 列表与播放页底；实现用系统 background。
- **Surface Secondary** (`#F2F2F7` → `{colors.surface-secondary}`): grouped / form 区背景（截图连接页）。
- **Placeholder Wash** (`#8E8E9333` → `{colors.placeholder}`): 封面未加载、格式徽章底。

### Semantic
- **Alert Red** (`#FF3B30` → `{colors.error}`): 列表错误文案与警告图标。唯一允许的高饱和非 accent 色。
- **On Accent** (`#FFFFFF` → `{colors.on-accent}`): 主播放键上的图标。

### Named Rules
**The One Tint Rule.** 任意屏幕上，accent 只出现在可操作项与「当前状态」上，占比宜 ≤10%。装饰性大色块、全屏渐变品牌墙禁止出现在正式 UI（截图展示模式可例外，但不得回写进产品页）。

**The Semantic First Rule.** 新颜色先问有没有系统语义色。有则用语义色；没有才加命名 token。硬编码 hex 不得替代 `Color.primary` / `secondary` / `accentColor`。

## Typography

**Display Font:** SF Pro（系统）
**Body Font:** SF Pro（系统）
**Label/Mono Font:** SF Pro + `monospacedDigit()`（时间码）

**Character:** 单一系统无衬线，靠字号与字重分层。清晰、直接；没有 display 花体，没有第二字体家族。

### Hierarchy
- **Title 2** (semibold, 22pt): 播放页曲名。
- **Body** (regular / semibold, 17pt): 列表曲名；当前曲用 semibold。
- **Subheadline** (regular / semibold, 15pt): 艺人·专辑、工具栏「正在播放」。
- **Footnote** (regular, 13pt): 错误文案、连接说明。
- **Caption / Caption 2** (medium, 12 / 11pt): 时间码、格式 / 本地徽章。
- **Time Mono** (medium caption + monospaced digits): 进度左右时间，保证跳动时不抖宽。

### Named Rules
**The Dynamic Type Rule.** 使用 SwiftUI 文字样式（`.title2`、`.body`、`.subheadline`…），禁止为了「更设计」写死 pt 覆盖动态字体。

**The No Display Face Rule.** UI 标签、按钮、数据一律 SF。禁止为产品页引入展示字体或全大写宽字距标题。

## Elevation

默认平面，靠选中色调与字重建立层次；关键可拖控件允许轻微抬起，让手指知道「这里能拖」。

列表当前曲用 `{colors.accent-soft}` 铺底，不用投影。封面是圆角矩形色块，无投影。唯一常规阴影在进度旋钮：静止 `0 2px 4px {colors.knob-shadow}`，拖动时加深到约 `0 2px 8px`、不透明度更高。

### Shadow Vocabulary
- **Knob Rest** (`0 2px 4px rgba(0,0,0,0.12)`): 进度旋钮默认。
- **Knob Drag** (`0 2px 8px rgba(0,0,0,0.22)`): 拖动进度时；配合旋钮从 12pt 放大到 16pt。

### Named Rules
**The Soft Lift On Controls Rule.** 阴影只服务可交互控件的按压 / 拖动反馈。禁止卡片墙、列表行、封面使用装饰性大模糊阴影。

**The Flat List Rule.** 歌曲行靠 tint 洗底与字重表达「正在播放」，不靠 elevation。

## Components

组件手感：**Familiar and decisive** — 熟悉系统控件，主操作一眼能点。

### Buttons
- **Play (primary):** 圆形 `borderedProminent`，tint 填充，内边距 16pt，图标 `.largeTitle`。这是屏幕上唯一的强填充主按钮。
- **Transport (prev / next):** 纯图标 `.title2`，无底，与播放键间距 40pt。
- **Toolbar link:** 小号 `bordered` 或浅蓝 Capsule 底（`accent-soft`）+ 半粗 subheadline，用于「正在播放」。
- **Refresh:** SF Symbol `arrow.clockwise`，加载中换成 `ProgressView`。

### Chips / Badges
- **Format badge:** 次要洗底 + 次要字，Capsule，caption2。
- **Local badge:** accent-soft 底 + accent 字，表示命中本地音频缓存。同一行可并排，间距 6pt。

### Cards / Containers
- **Cover art:** 260×260，圆角 16pt，未加载用 gray 洗底 + `music.note`。正式 UI 不用 24pt 大圆角英雄封面（那是截图模式）。
- **No content cards:** 列表不是卡片墙；用 inset `List`。

### Inputs / Fields
- 正式 App 暂无登录表单。截图连接页用 grouped `Form`：标签清晰、主操作一条填充条（圆角 8pt）。未来配置页沿用系统 Form，不自造输入皮肤。

### Navigation
- `NavigationStack` + large/inline 标题。「歌曲」为顶栏标题；播放页标题空、inline。
- 顶栏左侧进播放器，右侧刷新。保持系统返回手势可用。

### Lists
- `listStyle(.inset)`。行：左文案（标题 + 副标题），右可选 `ProgressView`（pending）。
- 当前曲：semibold 标题 + `accent-soft` 行底；切歌时 `easeInOut(0.35)` 滚到中间。
- 触控目标保持系统行高；垂直内边距约 9pt。

### Signature: Music Progress Bar
- 轨道高 6pt Capsule：track → buffered → accent 填充渐变。
- 白色旋钮描边 accent；拖动时放大并 soft/light 触感反馈。
- 时长未知时整体半透明且不可拖。

### Play Mode Picker
- 系统 `Picker` + `.segmented`：顺序 / 随机 / 单曲循环。禁止自绘三段胶囊替代。

## Do's and Don'ts

### Do:
- **Do** 用系统语义色与文字样式，保证 Dynamic Type、Dark Mode、辅助功能对比度。
- **Do** 把唯一强填充按钮留给播放 / 暂停。
- **Do** 用 accent 洗底或字重标出「当前曲」，并在切歌时滚动对齐。
- **Do** 错误用 `{colors.error}` 直接写在列表顶部，文案可读。
- **Do** 进度与运输控件保持大触控区（≥44pt）与明确触感反馈。
- **Do** 尊重 Reduce Motion：必要时用交叉淡入替代大位移动画。

### Don't:
- **Don't** 做成花哨的流媒体 App：强品牌色、大卡片墙、营销感强。
- **Don't** 做成信息过载的库管理工具：控件密、设置深、像后台。
- **Don't** 使用过度拟物 / 炫技动效：玻璃、光晕、夸张转场。
- **Don't** 在正式播放/列表页使用截图模式里的蓝青靛封面渐变作为默认视觉。
- **Don't** 给列表行或封面加大面积装饰阴影。
- **Don't** 引入第二品牌色或 display 字体来「做出差异」。
- **Don't** 用自动回退 / 自愈动画掩盖播放或网络失败。
