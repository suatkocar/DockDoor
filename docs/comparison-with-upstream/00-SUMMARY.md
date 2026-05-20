# DockDoor Upstream Analysis Summary

**Date:** March 9, 2026
**Scope:** Changes in ejbills/DockDoor since suatkocar's last merged PR #926 (Dec 18, 2025)
**Upstream versions covered:** v1.29 → v1.32.1 (3 months, 100+ commits)

---

## Executive Summary

The upstream repo has undergone **massive changes** in 3 months — 2 mega releases (1.31, 1.32), a complete settings UI overhaul, 37+ bug fixes, and significant architectural refactoring. Meanwhile, the local-usage branch has developed unique performance optimizations and features that upstream lacks. **Merge complexity is HIGH** due to divergent architectures.

---

## Reports

| # | Report | Key Finding |
|---|--------|-------------|
| 01 | [New Features](01-new-features.md) | 38 new features; settings overhaul, AppleScript support, mega perf PR |
| 02 | [Bug Fixes & Performance](02-bugfixes-performance.md) | 37+ fixes missing; 4 critical (crashes, memory leak), 16 major |
| 03 | [Architecture Comparison](03-architecture-comparison.md) | Local fork wins on render perf; upstream wins on settings UI + window merge |
| 04 | [UX & Settings](04-ux-settings-comparison.md) | ~50 keys unique to upstream, ~35 unique to local; settings org much better upstream |
| 05 | [Local-Usage Unique](05-local-usage-unique.md) | 12 unique commits; SelectionState, settings cache, bin-packing, windowless apps |

---

## What Upstream Has That We Don't

### Critical (should adopt)
- **4 crash fixes** — LimitedTaskGroup crash, dock icon click crash, wake-from-sleep failure, media widget memory leak
- **Event tap lag fix** — expensive AX calls on every keyDown moved off hot path
- **Stale cache fixes** — windows with wrong space IDs, dock hover not refreshing
- **Space filtering** — broken for dock previews and Cmd+Tab in our branch

### Major Features
- **Settings reorganization** — 10 feature-focused tabs with reusable components
- **AppleScript scripting dictionary** — full automation support
- **Window order persistence** — survives app restart
- **`mergeWindowsIfShowing()`** — seamless window list updates without flicker
- **Dock preview position anchoring** — prevents preview jumps with auto-hide dock
- **Cmd+Tab backward navigation** with Shift
- **Manual dark mode override**
- **Force window switcher direction**
- **Customizable Cmd+Tab cycle key and search trigger key**

### Performance
- AX observer work off main thread
- Structured concurrency (replaced LimitedTaskGroup)
- Cache-first dock hover (instant display, background refresh)
- Window discovery timeouts (Office apps: 8-20s → bounded)
- Lazy stacks for large window lists

---

## What We Have That Upstream Doesn't

### Genuine Improvements (upstream would benefit)
- **SelectionState separation** — fixes cursor disappearance + scroll blocking in other windows
- **WindowPreviewSettingsCache** — eliminates 600+ UserDefaults reads per switcher show
- **NSHostingView reuse** — saves 50-70ms per activation
- **Image count in cache keys** — fixes stale dimension caching
- **First-activation vertical clipping fix** — layoutSubtreeIfNeeded + deferred correction
- **HeaderStyleModifier** — eliminates ~80 lines duplicated code
- **Dimension cache tracks isWindowSwitcherActive** — prevents stale calculations

### Unique Features
- **Windowless app detection** (ElectronAppRegistry, MockWindowProvider, background refresh)
- **Width-based bin-packing layout** (replaces fixed column counts)
- **Liquid Glass fine-tuning** (19 glass variants, border/opacity controls)
- **Edge scrolling system** (speed, dynamic acceleration, directional)
- **4-directional switcher gestures**
- **Traffic light tooltips + hover effects toggle**
- **Performance profiles** (Default/Snappy/Relaxed)

### Things We Lost (regressions vs upstream)
- `mergeWindowsIfShowing()` — seamless window updates
- Event tap health checks
- Operation timeout wrappers
- Dock hover instant display (we're async-only)
- `VStack` instead of `LazyVStack` (memory concern with many windows)

---

## Merge Strategy Recommendation

**Option A: Full rebase onto upstream main** (recommended if planning future contributions)
- Highest effort, cleanest result
- Re-apply our 12 unique commits on top of current main
- Risk: many conflicts in consts.swift, settings views, coordinator

**Option B: Selective cherry-pick from upstream** (recommended for personal use)
- Cherry-pick critical crash fixes first
- Then cherry-pick performance improvements
- Then adopt settings architecture if desired
- Keep our unique features as-is

**Option C: Stay diverged** (current state)
- Continue with local-usage as personal fork
- Accept missing bug fixes and features
- Lowest effort but growing divergence

### Suggested Priority Order (for Option B)
1. Critical crash fixes (LimitedTaskGroup, dock icon, wake-from-sleep)
2. Event tap lag fix
3. Stale cache + space filtering fixes
4. `mergeWindowsIfShowing()` for better UX
5. Settings architecture (biggest effort, biggest UX win)
6. Window order persistence
7. AppleScript support
