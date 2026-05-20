# Upstream Bug Fixes and Performance Improvements Analysis

**Date:** 2026-03-09
**Scope:** Changes in ejbills/DockDoor main branch since December 18, 2025 (after PR #926)
**Branch comparison:** `local-usage` diverged from `main` at commit `f51abe8` (Dec 22, 2025)

---

## Summary

Since PR #926 was merged on December 18, 2025, there have been **37+ bug fix commits** and several significant performance improvements on the upstream `main` branch. Of these, only **4 fix commits** are present in the `local-usage` branch (via the pre-divergence merge). The remaining **33+ fixes** are **missing** from `local-usage` and represent bugs that likely affect it.

Two major releases occurred in this period:
- **v1.31** (Jan 2026) -- massive release with AppleScript support, concurrency fixes, cache architecture overhaul, media widget fixes
- **v1.32** (Mar 2026) -- FlowLayout system, dock auto-hide improvements, Tab hijacking fix, multiple layout fixes

---

## Fixes Already Present in local-usage

These fixes were merged before `local-usage` diverged or were cherry-picked:

| Commit | Fix | Notes |
|--------|-----|-------|
| `eafdb8e` | PR #939: cursor style leak, compact hover, search collapse, sidebar button | Merged Dec 20 |
| `b0f5359` | PR #938: window names not updated on app restart, screen recording popup | Merged Dec 22 |
| `40ff799` | PR #963: hide minimized/hidden labels in compact mode | Merged Dec 22 |
| `844441f` | Reject ghost windows on active space but not on screen | Merged Dec 22 |
| `f51abe8` | Full size preview option triggering after clicking on window | Merge point |

---

## Fixes MISSING from local-usage

### Category 1: Critical Fixes (Crashes and Data Loss)

#### 1. Replace LimitedTaskGroup with structured concurrency to prevent crash
- **Commit:** `1c5b315` (Jan 8, 2026)
- **Author:** ejbills
- **Severity:** CRITICAL
- **What it fixed:** `LimitedTaskGroup` had concurrency issues that could cause crashes during window discovery. Replaced with structured concurrency using proper task groups and timeouts.
- **Files changed:** `LimitedTaskGroup.swift`, `WindowUtil.swift`
- **Impact on local-usage:** YES -- `local-usage` uses the same `LimitedTaskGroup` implementation and is vulnerable to the same crash. This is one of the most important fixes to backport.

#### 2. DockDoor crash on click of own icon
- **Commit:** `244a19e` (Jan 17, 2026)
- **Author:** ejbills
- **Severity:** CRITICAL
- **What it fixed:** Clicking DockDoor's own dock icon caused the app to crash. Added guard in `DockObserver.swift` and `WindowUtil.swift` to handle self-referencing correctly.
- **Closes:** #1048
- **Impact on local-usage:** YES -- `local-usage` has the same `DockObserver` logic and will crash on self-click.

#### 3. Prevent osascript process pileup and reduce LaunchServices load (in v1.31)
- **Commit:** Part of `70984b6` (v1.31 release)
- **Author:** ejbills
- **Severity:** CRITICAL
- **What it fixed:** Rapidly hovering dock icons caused `launchservicesd` CPU spikes and lag due to `NSAppleScript` thread safety issues. Replaced with process-based `osascript` execution via `OSAScriptRunner`.
- **Impact on local-usage:** YES -- `local-usage` still uses the old `NSAppleScript` approach for media controls, which can cause process pileup and crashes.

#### 4. Fix media widget memory leak and process pileup (in v1.31)
- **Commit:** Part of `70984b6` (v1.31 release)
- **Author:** ejbills
- **Severity:** CRITICAL
- **What it fixed:** `MediaInfo` instances were not properly managed, causing RAM to climb to 400MB+ and the widget to die after rapid hovers. Restored singleton cache with view lifecycle management.
- **Closes:** #1038, #967
- **Impact on local-usage:** YES -- `local-usage` has the same media widget architecture and is vulnerable to this memory leak.

---

### Category 2: Major Fixes (Significant User-Facing Bugs)

#### 5. Activate application to re-assert window level on wake from sleep
- **Commit:** `702cb28` (Jan 17, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **What it fixed:** After waking from sleep, dock preview windows would not render. Added wake-from-sleep handler in `AppDelegate.swift` that re-asserts the application's window level.
- **Files changed:** `AppDelegate.swift` (+14 lines)
- **Impact on local-usage:** YES -- `local-usage` has no sleep/wake recovery logic. Users will experience broken previews after sleep.

#### 6. Apps with windows in cache not fetching new active windows on dock hover
- **Commit:** `153301a` (Jan 17, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **What it fixed:** When an app had windows in the cache, hovering over its dock icon would show stale cached windows instead of fetching newly opened windows. Reworked the cache-vs-refresh logic in `DockObserver.swift`.
- **Impact on local-usage:** YES -- `local-usage` has similar cache-first logic and likely suffers from the same staleness issue.

#### 7. Block windows with stale space IDs from entering cache
- **Commit:** `bc65203` (Jan 31, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **Closes:** #1075
- **What it fixed:** Windows with outdated space IDs were entering the cache, causing them to appear in previews for the wrong Space. Added validation in `WindowDiscoveryShared.swift` before cache insertion.
- **Impact on local-usage:** YES -- `local-usage` has the same `WindowDiscoveryShared` logic without the space ID validation.

#### 8. Event tap lag, dock click minimizing new windows, space filter on cached previews
- **Commit:** `7773236` (Feb 16, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **Closes:** #1095, #932, #1071
- **What it fixed:** Three bugs in one commit:
  1. **Event tap lag:** `shouldIgnoreKeybindForFrontmostApp()` was called on every keyDown event, making expensive AX calls. Deferred until after keycode matching.
  2. **Dock click minimizing new windows:** When clicking a dock icon for an app with no windows, the app would open then immediately minimize. Added window count tracking at click time.
  3. **Space filter on cached previews:** Cached dock preview windows were not filtered by current space. Added synchronous space filter before display.
- **Impact on local-usage:** YES -- all three issues likely affect `local-usage`. The event tap lag in particular degrades overall system responsiveness.

#### 9. Space filtering not working for dock previews and Cmd+Tab
- **Commit:** `5f9f512` (Feb 22, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **Closes:** #1071
- **What it fixed:** The space filtering feature was not actually working for dock previews or Cmd+Tab mode. Reworked the filtering logic across `DockObserver+CmdTab.swift`, `DockObserver.swift`, `KeybindHelper.swift`, and `WindowUtil.swift`.
- **Impact on local-usage:** YES -- `local-usage` has no working space filtering.

#### 10. Liquid glass freezing after window server marks window no longer aware
- **Commit:** `c6fadd3` (Feb 22, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **What it fixed:** The liquid glass (blur) visual effect would freeze when the window server flagged the window as no longer "aware." Added recovery logic in `BlurView.swift` (+42 lines).
- **Impact on local-usage:** YES -- `local-usage` uses the same `BlurView` without recovery logic. Users on macOS 26 Tahoe may experience frozen blur effects.

#### 11. Gate dock click action by checking if mouse within preview window
- **Commit:** `ffdfa8a` (Jan 17, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **Closes:** #1046
- **What it fixed:** Dock click actions (minimize/hide) were triggering even when the user clicked outside the preview area. Added mouse position check in `DockObserver.swift`.
- **Impact on local-usage:** YES -- `local-usage` will incorrectly fire dock click actions when clicking outside the preview.

#### 12. Remove hide window call on hover of application with no active windows
- **Commit:** `bef15dc` (Jan 17, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **Closes:** #1047
- **What it fixed:** Hovering over a dock icon for an app with no active windows caused DockDoor to call `hideWindow()`, which could interfere with the dock or other windows.
- **Impact on local-usage:** YES -- same `DockObserver` code path exists.

#### 13. Preview state presented from cache interfering with refreshed background values
- **Commit:** `8fc4357` (Jan 20, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **Closes:** #1054
- **What it fixed:** When a preview was shown from cache, the cached state's background color values would override the freshly computed values after the background refresh completed. Fixed coordination between cache and refresh in `PreviewStateCoordinator`.
- **Impact on local-usage:** YES -- `local-usage` has `PreviewStateCoordinator` with the same issue.

#### 14. Window switcher layout, search hotkey bugs, media scroll hijacking
- **Commit:** `aa73b51` (Feb 11, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **Closes:** #1088
- **What it fixed:** Three issues:
  1. Window switcher layout miscalculations in `Window Image Sizing Calculations.swift`
  2. Search hotkey not working correctly in `KeybindHelper.swift`
  3. Media widget scroll events being consumed by the preview instead of passed through
- **Files changed:** 10 files
- **Impact on local-usage:** PARTIAL -- `local-usage` has its own layout logic that may avoid some of these, but the search hotkey and media scroll issues likely exist.

#### 15. Window switcher rendering using stale orientation flag
- **Commit:** `156efee` (Feb 18, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **Closes:** #1103
- **What it fixed:** Separate code paths for determining window switcher orientation (horizontal vs vertical) could become misaligned, causing the switcher to render with the wrong layout.
- **Impact on local-usage:** YES -- `local-usage` has the same multi-path orientation logic.

#### 16. Preserve window order for non-grouped apps in switcher
- **Commit:** `c6d810d` / PR #985 (Dec 29, 2025)
- **Author:** maddada
- **Severity:** MAJOR
- **What it fixed:** When "Group Windows by App" was enabled, non-grouped apps also had their windows reordered (stuck together), destroying the original sorted order. Fixed with O(n) single-pass algorithm.
- **Impact on local-usage:** YES -- `local-usage` has the same broken grouping logic.

#### 17. Active app indicator in fullscreen + dock size changes
- **Commit:** `79eb757` / PR #1051 (Jan 21, 2026)
- **Author:** maddada
- **Severity:** MAJOR
- **Closes:** #899
- **What it fixed:** The active app indicator dot was:
  1. Appearing in full-screen spaces where it should not
  2. Getting misaligned when dock size changed (app opened/closed)
  3. Interfering with minimize genie effect
- **Impact on local-usage:** YES -- `local-usage` has the same indicator logic.

#### 18. Stop Tab hijacking in Cmd+Tab mode and double-press index reset
- **Commit:** `45b56c3` / PR #1100 (Feb 23, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **What it fixed:** Tab key in Cmd+Tab mode was cycling DockDoor previews instead of passing through to the system switcher. Also, rapid double-pressing Cmd+Tab lost the advanced selection due to early session-kill resetting the index.
- **Impact on local-usage:** YES -- `local-usage` has the same Cmd+Tab handler.

#### 19. Restore dock auto-hide state even when preview is not visible
- **Commit:** `3fa5e2f` / PR #668 (Feb 23, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **What it fixed:** `restoreDockState()` was called after an `isVisible` guard in `hideWindow()`, meaning if the preview was dismissed before becoming visible, the dock would remain hidden permanently.
- **Impact on local-usage:** YES -- `local-usage` has the same ordering bug in `SharedPreviewWindowCoordinator`.

#### 20. Prevent preview bounce from duplicate AX notifications on dock auto-hide
- **Commit:** `0a944a7` (Feb 23, 2026)
- **Author:** ejbills
- **Severity:** MAJOR
- **What it fixed:** With dock auto-hide set to 0s animation, AX selected-children notifications fire repeatedly for the same icon, causing the preview to bounce/reposition. Added element identity tracking to skip redundant display requests.
- **Impact on local-usage:** YES -- `local-usage` has no duplicate notification suppression.

---

### Category 3: Minor Fixes (UI Polish and Edge Cases)

#### 21. Window preview radius
- **Commit:** `82a72a2` (Jan 8, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **Closes:** #1008
- **What it fixed:** Window preview corner radius was incorrect in `dockStyle.swift` and `WindowPreviewHoverContainer.swift`.
- **Impact on local-usage:** YES -- same rendering code.

#### 22. Animation timing not respected and macOS 26 internal animation
- **Commit:** `e6c51e3` (Jan 8, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **Closes:** #1007
- **What it fixed:** Application windows were using macOS's internal animation timing instead of DockDoor's configured timing. Set `animationBehavior = .none` on all application windows.
- **Impact on local-usage:** YES -- `local-usage` windows use default animation behavior.

#### 23. Suppress tap gesture during trackpad swipe
- **Commit:** `da32b7f` / PR #934 (Feb 23, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **What it fixed:** Fast trackpad swipes incorrectly triggered tap actions (hidden window toggle). Added suppression during and briefly after scrolling.
- **Impact on local-usage:** YES -- same gesture handling code.

#### 24. Widget spacing not scaling with globalPaddingMultiplier
- **Commit:** `9a942f5` / PR #919 (Feb 23, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **What it fixed:** `SharedHoverAppTitle` used hardcoded padding that did not scale with the user's spacing multiplier.
- **Impact on local-usage:** YES -- same hardcoded padding.

#### 25. Preserve validation flag across debounced AX event cancellations
- **Commit:** `7bc2f00` (Feb 23, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **What it fixed:** When a subsequent AX event cancelled a pending destroy handler, the `needsValidation` flag was lost. Also changed cache validation timer from hardcoded 30s to configurable (default 60s).
- **Impact on local-usage:** YES -- same debounce logic in `WindowManipulationObservers`.

#### 26. Remove background cache validation timer to stop screen recording popup
- **Commit:** `9ee639a` (Feb 26, 2026)
- **Author:** ejbills
- **Severity:** MINOR (but annoying to users)
- **What it fixed:** The periodic `cacheValidationTimer` triggered `ScreenCaptureKit` calls that caused the screen recording notification to appear repeatedly. Replaced with throttled refresh on keybind activation only.
- **Impact on local-usage:** PARTIAL -- `local-usage` may have a different cache validation approach, but if it uses periodic timers, the same issue exists.

#### 27. FlowLayout placing items outside visible bounds
- **Commit:** `7e0ed5c` (Feb 26, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **What it fixed:** `sizeThatFits` was called multiple times with different proposals; cached lines from the last call could mismatch actual bounds, causing items to be placed off-screen.
- **Impact on local-usage:** NO -- `local-usage` does not have the FlowLayout system. However, it may have equivalent issues with its own layout code.

#### 28. Only quit app on close when it is the last window
- **Commit:** `3130e07` (Feb 26, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **What it fixed:** The "quit app on window close" feature always quit the app regardless of how many windows remained, making the close button act as a quit button.
- **Impact on local-usage:** NO -- `local-usage` does not have the "quit app on window close" feature.

#### 29. Settings window resize
- **Commit:** `b50e8e9` (Feb 26, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **Closes:** #1113
- **What it fixed:** Settings window was not resizing properly.
- **Impact on local-usage:** YES -- same settings window code.

#### 30. Initial selection being reset
- **Commit:** `577d670` (Feb 23, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **What it fixed:** The initial window selection in the switcher was being reset unexpectedly.
- **Closes:** #1110
- **Impact on local-usage:** YES -- same selection logic.

#### 31. Require exact modifier match for keyboard shortcuts
- **Commit:** `6edce2c` (Dec 29, 2025)
- **Author:** ejbills (on main, not in local-usage)
- **Severity:** MINOR
- **What it fixed:** Keyboard shortcuts triggered even with extra modifiers pressed (e.g., Option+K would also trigger on Cmd+Option+K). Changed from OR-based "contains" to AND-based exact match.
- **Impact on local-usage:** YES -- `local-usage` has the old OR-based matching.

#### 32. Correct title/controls position in parallel embedded layout
- **Commit:** `76ef6d0` (Mar 2, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **Closes:** #1128
- **What it fixed:** The four parallel layout cases in `embeddedDockPreviewControls()` had the Spacer on the wrong side, pushing elements to the wrong horizontal position.
- **Impact on local-usage:** YES -- `local-usage` has parallel layout support from PR #977 (present in main but not merged into local-usage).

#### 33. Live preview dock gap
- **Commit:** `60ce645` (Mar 2, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **What it fixed:** Live preview images had incorrect aspect ratio because `scaledToFit` was missing from the inner Image in `LivePreviewImage`, causing SwiftUI to default to 1:1 from `resizable()`.
- **Impact on local-usage:** YES -- `local-usage` has live preview with the same missing modifier.

#### 34. Flow behavior for window switcher not using max cols
- **Commit:** `1f68848` (Mar 2, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **What it fixed:** Window switcher flow layout was not respecting the maximum columns setting.
- **Impact on local-usage:** PARTIAL -- `local-usage` has its own layout logic but similar column calculations.

#### 35. Compact mode sizing
- **Commit:** `8cc4617` (Mar 1, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **What it fixed:** Compact mode sizing was incorrect in `PreviewStateCoordinator`.
- **Impact on local-usage:** YES -- same `PreviewStateCoordinator` code.

#### 36. Decouple window cache refresh from switcher activation
- **Commit:** `8bcc17b` (Feb 22, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **Closes:** #1054
- **What it fixed:** Window cache refresh was coupled to switcher activation, causing unnecessary refreshes. Moved to `WindowManipulationObservers`.
- **Impact on local-usage:** YES -- same coupled logic.

#### 37. Dynamic sizing panel width
- **Commit:** `6d3fabe` (Mar 1, 2026)
- **Author:** ejbills
- **Severity:** MINOR
- **What it fixed:** Panel width was computed incorrectly for horizontal flow; scroll direction was wrongly coupled to flow direction.
- **Impact on local-usage:** PARTIAL -- `local-usage` has its own sizing logic.

---

## Performance Improvements

### 1. Event Tap Optimization (in `7773236`)
- **Impact:** HIGH
- Deferred `shouldIgnoreKeybindForFrontmostApp()` until after keycode matching to avoid expensive AX calls on every keyDown event. This was causing system-wide input lag.
- **Missing from local-usage:** YES

### 2. Structured Concurrency Migration (in `1c5b315`)
- **Impact:** HIGH
- Replaced `LimitedTaskGroup` with proper Swift structured concurrency (task groups with timeouts). Eliminates crash potential and improves cleanup on cancellation.
- **Missing from local-usage:** YES

### 3. Cache Architecture Overhaul (in v1.31 release `70984b6`)
- **Impact:** HIGH
- Non-blocking window preview loading with cache-first approach
- Batch cache reads to reduce stutter
- Pre-compute skip sets at batch level instead of per-window cache reads
- AX observer work moved off main thread to prevent UI hangs
- Debounced AX observer callbacks
- **Missing from local-usage:** YES

### 4. Window Discovery Timeout (in v1.31 release)
- **Impact:** MEDIUM
- Added 2-second time limit to `windowsByBruteForce` AX enumeration which was taking 8-20+ seconds for problematic apps like Microsoft Office
- Added proper cancellation checks in `LimitedConcurrency` loops
- **Missing from local-usage:** YES

### 5. Media Widget Process Pileup Prevention (in v1.31 release)
- **Impact:** MEDIUM
- Replaced `NSAppleScript` (not thread-safe) with process-based `osascript` execution
- Prevents `launchservicesd` CPU spikes when rapidly hovering dock icons
- **Missing from local-usage:** YES

### 6. Hover Performance Optimization (in `a247a09`)
- **Impact:** MEDIUM
- Optimized hover handler for window previews to reduce CPU usage during mouse movement
- **Missing from local-usage:** YES (pre-divergence fix, but on main branch after divergence point)

### 7. Preview Bounce Elimination (in `0a944a7`)
- **Impact:** MEDIUM
- Eliminated redundant display pipeline re-runs when dock auto-hides with 0s animation
- Moved AX position/size queries off the main thread
- **Missing from local-usage:** YES

### 8. FlowLayout System (in `d827244`)
- **Impact:** MEDIUM
- Replaced chunked grid layout with SwiftUI Layout protocol
- Eliminates hardcoded spacing estimates and duplicated grid computation
- Real child size measurement instead of estimation
- **Missing from local-usage:** YES (though local-usage has its own layout approach)

---

## Priority Ranking for Backporting

### Must Have (Critical)
1. `1c5b315` -- LimitedTaskGroup crash fix (structured concurrency)
2. `244a19e` -- DD crash on click of own icon
3. `702cb28` -- Wake from sleep preview rendering fix
4. v1.31 media/osascript fixes -- Memory leak and process pileup prevention

### Should Have (Major)
5. `153301a` -- Stale cache not refreshing on dock hover
6. `bc65203` -- Stale space IDs entering cache
7. `7773236` -- Event tap lag (performance), dock click minimizing, space filter
8. `5f9f512` -- Space filtering for dock previews and Cmd+Tab
9. `c6fadd3` -- Liquid glass freezing recovery
10. `ffdfa8a` -- Dock click action mouse position check
11. `bef15dc` -- Hide window call on no-windows hover
12. `8fc4357` -- Cache state interfering with background refresh
13. `aa73b51` -- Window switcher layout and search hotkey bugs
14. `156efee` -- Stale orientation flag rendering
15. `c6d810d` -- Non-grouped app window order preservation
16. `79eb757` -- Active app indicator fullscreen + dock size
17. `45b56c3` -- Tab hijacking in Cmd+Tab mode
18. `3fa5e2f` -- Dock auto-hide state restoration
19. `0a944a7` -- Preview bounce from duplicate AX notifications

### Nice to Have (Minor)
20. `82a72a2` -- Window preview radius
21. `e6c51e3` -- Animation timing / macOS 26
22. `da32b7f` -- Trackpad swipe tap suppression
23. `9a942f5` -- Widget spacing scaling
24. `7bc2f00` -- Validation flag preservation
25. `9ee639a` -- Screen recording popup from cache timer
26. `b50e8e9` -- Settings window resize
27. `577d670` -- Initial selection reset
28. `6edce2c` -- Exact modifier match for shortcuts
29. `76ef6d0` -- Parallel embedded layout position
30. `60ce645` -- Live preview dock gap
31. `8cc4617` -- Compact mode sizing

---

## Key Observations

1. **The `local-usage` branch is significantly behind on stability fixes.** It diverged at `f51abe8` (Dec 22, 2025) and has missed 3 months of bug fixes, including 4 critical crash/memory fixes and 16 major user-facing bugs.

2. **The v1.31 release (`70984b6`) was a massive stability release** that included dozens of fixes bundled into a single commit. Many of these address architectural issues (main thread blocking, AX observer work queuing, media singleton lifecycle) that cannot be trivially cherry-picked.

3. **Cache and concurrency architecture has been significantly reworked** upstream. The `local-usage` branch still has the old architecture, making it vulnerable to stale caches, main-thread hangs, and race conditions.

4. **The FlowLayout system** introduced in v1.32 is a complete replacement of the layout engine. `local-usage` has its own layout modifications but does not benefit from this new system.

5. **Sleep/wake recovery** is entirely missing from `local-usage`. This is a common user complaint that was addressed in January 2026.

6. **Space filtering** -- a feature many users rely on -- does not work correctly in `local-usage`.

7. **Direct cherry-picking may be difficult** for many of these fixes because upstream has restructured files significantly (settings reorganization in `e19292a`, corner radius system centralization, FlowLayout introduction). A rebase or selective merge strategy would be more practical.

---

## Recommendation

Before contributing new features from `local-usage`, the branch should be rebased or merged with current `main` to incorporate at minimum the critical and major fixes listed above. The local-usage branch's unique features (windowless app activation, width-based layout, live preview enhancements) should be re-applied on top of the current stable codebase to avoid shipping known bugs to users.
