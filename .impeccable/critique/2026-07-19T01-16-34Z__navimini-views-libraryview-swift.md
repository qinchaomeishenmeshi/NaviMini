---
target: LibraryView
total_score: 20
p0_count: 1
p1_count: 2
timestamp: 2026-07-19T01-16-34Z
slug: navimini-views-libraryview-swift
---
# Critique: LibraryView

**Target:** `NaviMini/Views/LibraryView.swift`
**Score:** 20/40 (Acceptable)
**Method:** dual-agent

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 2 | First load / empty refresh is a blank List; status only in tiny trailing spinner |
| 2 | Match System / Real World | 3 | Errors dump localizedDescription jargon |
| 3 | User Control and Freedom | 2 | Auto scrollTo yanks browse position; error has no dismiss |
| 4 | Consistency and Standards | 3 | Mostly HIG; Now Playing uses bordered vs DESIGN Capsule |
| 5 | Error Prevention | 2 | Refresh disabled while loading; little else |
| 6 | Recognition Rather Than Recall | 3 | Current row wash good; off-screen current needs memory |
| 7 | Flexibility and Efficiency | 1 | Tap / refresh / player only — intentional thinness |
| 8 | Aesthetic and Minimalist Design | 3 | Strong restraint; blank empty feels incomplete |
| 9 | Error Recovery | 1 | Red diagnosis, no adjacent Retry |
| 10 | Help and Documentation | 0 | No empty guidance |
| **Total** | | **20/40** | **Acceptable** |

## Anti-Patterns Verdict

**LLM assessment:** Not AI slop. Native inset List, SF type, single accent wash — passes product/iOS familiarity tests. Residual risk is unfinished states (blank first paint, technical errors), not decorative monoculture.

**Deterministic scan:** `detect.mjs --json` exit 0, findings `[]`. Empty result on SwiftUI is a web-rule non-hit, not proof of cleanliness.

**Visual overlays:** Skipped — native iOS, no HTML entry.

## Overall Impression

Happy-path list craft is on-brand and calm. The single biggest opportunity is making cold start, empty library, and errors as confident as the filled list.

## What's Working

1. On-brand restraint — Flat List Rule held; no screenshot gradient covers.
2. Micro-status vocabulary — current / pending / refreshing / loading-more without badge clutter.
3. Honest errors — visible, not self-healing (recovery UX still missing).

## Priority Issues

### [P0] First-load / empty library is a silent void
- **Why:** Cold start and empty library look like a hang.
- **Fix:** ContentUnavailableView + loading copy when refreshing with empty songs.
- **Suggested command:** `$impeccable onboard LibraryView` / `$impeccable harden LibraryView`

### [P1] Error section diagnoses but does not recover
- **Why:** Retry only in top-trailing refresh; copy is technical.
- **Fix:** Inline 重新加载 + plain-language errors.
- **Suggested command:** `$impeccable clarify LibraryView` / `$impeccable harden LibraryView`

### [P1] Accessibility & Reduce Motion gaps on the main row
- **Why:** Rows lack current/pending VO; scroll animation ignores Reduce Motion; subtitle opacity hurts contrast.
- **Fix:** Row a11y labels; Reduce Motion → no animated scroll; drop extra opacity.
- **Suggested command:** `$impeccable audit LibraryView`

### [P2] Auto-scroll steals browse position
- **Why:** Lock-screen next while browsing yanks the list.
- **Fix:** Scroll only if off-screen, or explicit locate control.
- **Suggested command:** `$impeccable distill LibraryView`

### [P3] Now-playing entry under-communicates identity
- **Why:** Link never shows current title.
- **Fix:** Truncated current title in toolbar; optional duration.
- **Suggested command:** `$impeccable polish LibraryView`

## Persona Red Flags

**Casey (Distracted Mobile):** Top-trailing recovery; blank cold start; forced scrollTo.
**Sam (Accessibility):** Unlabeled current/pending rows; Reduce Motion ignored; color-heavy errors.
**QZX (personal Navidrome owner):** Anti-streaming look is right; silent empty + jargon errors undermine “stable.”

## Minor Observations

- Current-row horizontal padding causes subtle layout shift.
- Load-more ProgressView lacks a11y label.
- Do not copy ScreenshotSongRowView gradient covers into production.

## Questions to Consider

1. Should first paint of「歌曲」tell a loading/empty story as confidently as the filled list?
2. Is auto-centering current song a control or an interruption?
3. Does visible error without adjacent Retry recreate the admin-console vibe PRODUCT rejects?
