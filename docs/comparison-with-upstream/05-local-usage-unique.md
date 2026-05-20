# Local-Usage Branch: Unique Features and Modifications

**Compared against:** upstream `ejbills/DockDoor` (main, cloned 2026-03-09)
**Local branch:** `local-usage` at commit `5275af2`

This document catalogs every meaningful divergence between the `local-usage` branch and upstream, organized by area. For each item the analysis covers what it does, why it matters, whether upstream would benefit, and whether it is a personal preference or a genuine improvement.

---

## Table of Contents

1. [Architecture Changes](#1-architecture-changes)
2. [Window Switcher Layout System](#2-window-switcher-layout-system)
3. [Windowless App Detection and Handling](#3-windowless-app-detection-and-handling)
4. [Performance Optimizations](#4-performance-optimizations)
5. [Settings Cache System](#5-settings-cache-system)
6. [Selection State Separation](#6-selection-state-separation)
7. [Thumbnail and Cache Improvements](#7-thumbnail-and-cache-improvements)
8. [UI/UX Changes](#8-uiux-changes)
9. [Dock Observer Changes](#9-dock-observer-changes)
10. [Marquee Text Changes](#10-marquee-text-changes)
11. [Traffic Light Buttons Enhancements](#11-traffic-light-buttons-enhancements)
12. [Window Activation and Focus](#12-window-activation-and-focus)
13. [Settings and Configuration Differences](#13-settings-and-configuration-differences)
14. [Removed Features](#14-removed-features)
15. [New Files Only in Local-Usage](#15-new-files-only-in-local-usage)
16. [Summary and Recommendations](#16-summary-and-recommendations)

---

## 1. Architecture Changes

### 1.1 PreviewStateCoordinator is No Longer an ObservableObject

**What:** In upstream, `PreviewStateCoordinator` is a class conforming to `ObservableObject` with `@Published` properties (`currIndex`, `windowSwitcherActive`, `windows`, `shouldScrollToIndex`, etc.). In local-usage, it is a plain `final class` without `ObservableObject` conformance.

**Why it matters:** When `PreviewStateCoordinator` was `ObservableObject`, any property change triggered SwiftUI view updates across all subscribers. This caused scroll events in unrelated windows (e.g., Settings) to be blocked when the switcher was hidden but the coordinator still existed. Removing `ObservableObject` conformance eliminates spurious SwiftUI subscriptions.

**Upstream benefit:** Yes, significant. This is a genuine architectural improvement that fixes a real bug where scroll events in other windows were blocked by the preview coordinator's subscriptions.

**Classification:** Genuine improvement.

### 1.2 SelectionState as a Separate Lightweight ObservableObject

**What:** A new `SelectionState` class (`SelectionState.swift`) is introduced as a lightweight `ObservableObject` that only publishes `currentIndex`, `shouldScrollToIndex`, and `lastInputWasKeyboard`. The `PreviewStateCoordinator` delegates selection state to this object while keeping heavy state (windows array, dimensions) non-reactive.

**Why it matters:** This separation prevents full view hierarchy recreation when the selection index changes. Only the selection-related parts of the UI update, which fixes cursor disappearance during hover interactions and reduces unnecessary re-renders.

**Upstream benefit:** Yes. This is a well-designed pattern that improves responsiveness.

**Classification:** Genuine improvement.

### 1.3 WindowImageSizingCalculations Extracted to Standalone Enum

**What:** Upstream defines sizing calculations as extensions on `WindowPreviewHoverContainer`. Local-usage extracts them into a standalone `enum WindowImageSizingCalculations` with its own caching infrastructure.

**Why it matters:** Decouples layout calculation logic from the view hierarchy, making it reusable and testable. Also allows `WindowSwitcherStateManager` and `PreviewStateCoordinator` to call navigation functions without depending on the view container.

**Upstream benefit:** Moderate. Cleaner separation of concerns, but requires refactoring dependent code.

**Classification:** Genuine improvement (code organization).

### 1.4 WindowSwitcherStateManager

**What:** A new `WindowSwitcherStateManager` class (`WindowSwitcherStateManager.swift`) conforming to `IndexManaging` protocol manages window switcher state including index tracking, window IDs, search filtering, and grid navigation. It keeps a parallel state model that syncs with the UI coordinator.

**Why it matters:** Separates state management from UI rendering. The state manager tracks the "source of truth" for which window is selected, while the UI coordinator handles visual presentation. This dual-index approach allows the switcher to maintain correct state even when UI is not visible.

**Upstream benefit:** Yes. Cleaner state management, especially for handling quick modifier releases.

**Classification:** Genuine improvement.

### 1.5 IndexManaging Protocol

**What:** A new protocol `IndexManaging` (in `IndexManaging.swift`) provides a unified interface for index management across `WindowSwitcherStateManager` and other coordinators.

**Why it matters:** Enables polymorphic index management and reduces code duplication between different coordinator types.

**Upstream benefit:** Moderate. Good software design pattern.

**Classification:** Genuine improvement (code organization).

---

## 2. Window Switcher Layout System

### 2.1 Width-Based Bin-Packing Layout

**What:** Local-usage introduces a bin-packing layout algorithm (`createBinPackedChunks`) that places windows into rows based on their actual pixel width rather than a fixed column count. Controlled by `useWidthBasedLayout` (default: `true`) and `layoutWidthPercentage` (default: `0.90`).

**Why it matters:** When windows have varying aspect ratios (e.g., a tall Slack window next to a wide browser), fixed column counts waste space. Bin-packing fills rows to approximately 90% of screen width, giving a denser, more natural layout.

**Upstream benefit:** Yes, significant. This addresses a common complaint about wasted space in the window switcher when windows have different aspect ratios.

**Classification:** Genuine improvement.

### 2.2 Vertical Scroll Direction for Window Switcher

**What:** The window switcher always uses `.vertical` scroll direction. Upstream has a `windowSwitcherScrollDirection` setting that allows horizontal or vertical scrolling.

**Why it matters:** With multi-row bin-packing, vertical scrolling is the natural fit -- rows of windows stack downward. Horizontal scroll makes less sense when the layout already fills screen width.

**Upstream benefit:** Depends on whether bin-packing is adopted. Without bin-packing, horizontal scroll is still useful.

**Classification:** Design decision tied to bin-packing.

### 2.3 `switcherMaxColumns` Setting

**What:** Local-usage adds a `switcherMaxColumns` setting (default: 6) alongside `switcherMaxRows` (default: 2). Upstream only has `switcherMaxRows` (default: 8).

**Why it matters:** Provides more control over the grid layout. When `useWidthBasedLayout` is enabled, `switcherMaxColumns` serves as a fallback for navigation calculations.

**Upstream benefit:** Yes, if bin-packing is not adopted. Gives users finer control.

**Classification:** Genuine improvement.

### 2.4 `previewWindowSpacing` Setting

**What:** A configurable `previewWindowSpacing` setting (default: 24 points) replaces the hardcoded `HoverContainerPadding.itemSpacing`.

**Why it matters:** Users can customize spacing between preview windows to their preference.

**Upstream benefit:** Minor. The upstream hardcoded value of 24 is reasonable.

**Classification:** Personal preference / minor improvement.

### 2.5 VStack/HStack Instead of Lazy Variants

**What:** Local-usage uses `VStack`/`HStack` instead of upstream's `LazyVStack`/`LazyHStack` for the window preview grid.

**Why it matters:** Lazy stacks only render visible content, which is good for long lists but can cause layout instability and measurement issues with `fittingSize`. Non-lazy stacks ensure all items are measured upfront, preventing first-activation sizing bugs.

**Upstream benefit:** Debatable. For typical window counts (< 20), non-lazy stacks are fine. For users with many windows, lazy stacks are better for memory. The trade-off depends on the typical use case.

**Classification:** Trade-off. Fixes sizing bugs but may impact memory for large window counts.

### 2.6 Window Switcher Vertical Clipping Fix

**What:** Commits `5275af2` and `6bbe59b` specifically fix vertical clipping on first activation and layout overflow issues. The fixes include clamping window size to screen bounds, forcing `layoutSubtreeIfNeeded()` before querying `fittingSize`, and a deferred size correction on the next run-loop cycle.

**Why it matters:** On first activation, `NSHostingView.fittingSize` can return a too-small value because SwiftUI hasn't fully settled its layout. This caused the bottom of the switcher to be clipped. The deferred correction re-measures and adjusts the frame.

**Upstream benefit:** Yes, significant. This is a real bug fix for first-activation sizing.

**Classification:** Genuine bug fix.

---

## 3. Windowless App Detection and Handling

### 3.1 Complete Windowless App System

**What:** Local-usage implements a comprehensive windowless app detection and display system. Running apps that have no visible windows (e.g., a freshly launched Electron app, or an app whose windows were all closed) appear in the window switcher with just their app icon.

Key components:
- `MockWindowProvider` class for creating placeholder `WindowInfo` entries (windowID = 0)
- `WindowInfo.isWindowlessApp` computed property
- `getWindowlessApps()` function that detects running regular apps without visible windows
- Cached windowless app list with configurable refresh intervals
- `manuallyRefreshWindowlessApps()` for manual cache invalidation
- Background async refresh to avoid blocking UI

**Why it matters:** Without this, apps like Claude (Electron-based) that close their last window but remain running are invisible in the switcher. Users have no way to bring them back except clicking the Dock icon.

**Upstream benefit:** Yes, significant. This is a highly requested feature for power users who use Electron apps.

**Classification:** Genuine feature addition.

### 3.2 ElectronAppRegistry

**What:** A new centralized registry (`ElectronAppRegistry.swift`) that identifies Electron and Electron-like applications by bundle ID prefix or exact match. Contains ~50 known app prefixes (Slack, Discord, VS Code, Claude, etc.) and provides detection methods for:
- Whether an app is Electron-based
- Whether an app should be exempt from tabbed window filtering
- Exact bundle ID matching

**Why it matters:** Electron apps have special window management behavior (invisible background windows, frequent PID changes). This registry centralizes detection logic that was previously scattered or hardcoded.

**Upstream benefit:** Yes. Centralized app detection is better than ad-hoc checks.

**Classification:** Genuine improvement.

### 3.3 WindowlessAppDetectable Protocol

**What:** A protocol (`WindowlessAppDetectable.swift`) with a default implementation (`DefaultWindowlessAppDetector`) for detecting windowless applications. Enables dependency injection for testing.

**Why it matters:** Protocol-oriented design makes the windowless detection logic testable and swappable.

**Upstream benefit:** Moderate. Good design but the protocol is not widely used yet.

**Classification:** Over-engineering for current usage, but good for future extensibility.

### 3.4 Alt-Tab-macOS Compatibility Functions

**What:** Several functions ported from the alt-tab-macos project:
- `isActualApplication()` -- filters XPC processes, zombie processes
- `isNotXpc()` -- detects XPC service processes by bundle ID
- `isProcessZombie()` -- uses `proc_pidinfo` to detect zombie processes
- `calculateThumbnailSize()` -- alt-tab-macos's thumbnail sizing logic

**Why it matters:** These provide more accurate application detection and consistent thumbnail sizing with the well-established alt-tab-macos project.

**Upstream benefit:** Yes. More robust process filtering prevents ghost entries in the switcher.

**Classification:** Genuine improvement.

### 3.5 `isUserVisibleWindow()` Function

**What:** Checks if a window is truly user-visible by examining its CG layer, alpha, and dimensions. Windows with `layer != 0`, `alpha < 0.1`, or dimensions `< 100px` are considered invisible.

**Why it matters:** Prevents invisible helper windows (common in Electron apps) from being counted as real windows, which would prevent the app from being correctly identified as windowless.

**Upstream benefit:** Yes. Better window visibility detection.

**Classification:** Genuine improvement.

### 3.6 `filterOutTabbedWindows()` Function

**What:** Filters out windows that are not visible on screen and not in another space. Respects Electron app exemptions from `ElectronAppRegistry`.

**Why it matters:** Prevents stale tabbed windows from appearing in the switcher.

**Upstream benefit:** Yes, with caveats. The logic is specific to the windowless app system.

**Classification:** Genuine improvement (part of windowless app system).

---

## 4. Performance Optimizations

### 4.1 NSHostingView Reuse

**What:** `SharedPreviewWindowCoordinator` caches the `NSHostingView` instance and reuses it by updating `rootView` instead of creating a new `NSHostingView` on every show. When hiding, it sets the root view to `EmptyView()` to force SwiftUI view dismantling.

**Why it matters:** Creating `NSHostingView` costs ~30-50ms. Reusing it makes the switcher appear nearly instantly on subsequent activations.

**Upstream benefit:** Yes, significant. Measurable performance improvement.

**Classification:** Genuine improvement.

### 4.2 Cached Window Size for Instant Positioning

**What:** The coordinator caches the last computed `fittingSize` along with the window count and image count. When the same number of windows/images are shown again, it skips the expensive `fittingSize` calculation (~20-30ms).

**Why it matters:** `fittingSize` triggers a full SwiftUI layout pass. Caching eliminates this on repeated activations with the same window set.

**Upstream benefit:** Yes. Direct performance win.

**Classification:** Genuine improvement.

### 4.3 Image Count in Cache Keys

**What:** The dimension caching system includes the count of windows with non-nil images as part of cache invalidation keys. Upstream only tracks window count.

**Why it matters:** When thumbnails load asynchronously, the cache must invalidate when images arrive (not just when windows appear/disappear). Without image count tracking, dimensions can be stale until a full cache reset.

**Upstream benefit:** Yes. Fixes a subtle caching bug where dimensions don't update when thumbnails load.

**Classification:** Genuine bug fix.

### 4.4 Pre-Fetched CG Window List

**What:** Functions like `hasVisibleCachedWindows()`, `isUserVisibleWindow()`, and `shouldTreatAsWindowlessApp()` accept a pre-fetched `cgWindowList` parameter instead of calling `CGWindowListCopyWindowInfo()` internally.

**Why it matters:** `CGWindowListCopyWindowInfo()` is an IPC call to the window server, costing ~1-5ms each. When checking multiple windows, passing a pre-fetched list eliminates N+1 system calls.

**Upstream benefit:** Yes, significant for the windowless detection path. Not applicable if windowless detection is not adopted.

**Classification:** Genuine improvement.

### 4.5 Synchronous Window Switcher Initialization

**What:** `KeybindHelper` has a `handleWindowSwitchingSync()` path and `initializeWindowSwitchingSync()` that avoid async overhead for instant mode. Space refresh is throttled to avoid expensive API calls on every activation.

**Why it matters:** Eliminates the 100ms `Task.sleep` delay and async overhead for the instant switcher mode. Space API calls are throttled to every 0.5 seconds.

**Upstream benefit:** Yes. Faster switcher activation.

**Classification:** Genuine improvement.

### 4.6 `LimitedTaskGroup` for Concurrent Window Capture

**What:** Uses `LimitedTaskGroup` (max 4 concurrent tasks) for window capture and image refresh, replacing upstream's `LimitedConcurrency.forEachNonThrowing`.

**Why it matters:** Similar concurrency control with different implementation. The local version avoids the 10-second timeout wrapper.

**Upstream benefit:** Neutral. Different implementation, similar behavior.

**Classification:** Implementation preference.

### 4.7 Removed `DebugLogger.measureSlow` Wrappers

**What:** Several `DebugLogger.measureSlow` wrappers around `isValidElement` and dock hover operations are removed.

**Why it matters:** Reduces overhead from timing instrumentation in production code.

**Upstream benefit:** Minor. The measurement overhead is small, and logging is useful for debugging.

**Classification:** Personal preference.

### 4.8 CATransaction for Instant UI Updates

**What:** `updateContentView` wraps frame changes in `CATransaction.begin()/commit()` with `setDisableActions(true)` to prevent implicit CoreAnimation transitions.

**Why it matters:** Eliminates brief animation artifacts when the window frame changes.

**Upstream benefit:** Yes. Prevents visual glitches.

**Classification:** Genuine improvement.

---

## 5. Settings Cache System

### 5.1 WindowPreviewSettingsCache

**What:** A new `WindowPreviewSettingsCache` struct (`WindowPreviewSettingsCache.swift`) captures all `@Default` settings as a snapshot when the preview window is shown. Individual `WindowPreview` views read from this cache instead of calling `Defaults[.key]` on every render.

**Why it matters:** `@Default` property wrappers create KVO subscriptions and trigger view updates on every UserDefaults change. With 60+ settings read per `WindowPreview` instance, and potentially 10+ instances visible, this creates thousands of unnecessary subscriptions. The cache reads settings once and passes them as a struct.

**Upstream benefit:** Yes, significant. Measurable reduction in unnecessary view updates.

**Classification:** Genuine improvement.

### 5.2 HoverContainerSettingsCache

**What:** Similarly, a `HoverContainerSettingsCache` struct caches container-level settings for `WindowPreviewHoverContainer`.

**Upstream benefit:** Same as above.

**Classification:** Genuine improvement.

---

## 6. Selection State Separation

### 6.1 `isKeyboardScrolling` Flag

**What:** A new `isKeyboardScrolling` flag on `PreviewStateCoordinator` prevents mouse hover from overriding keyboard-initiated selections.

**Why it matters:** Without this, moving the mouse after pressing Tab could cause the selection to jump to whatever the cursor happens to be over, which is disorienting.

**Upstream benefit:** Yes. Better input mode handling.

**Classification:** Genuine improvement.

### 6.2 `lastInputWasKeyboard` Tracking

**What:** The `SelectionState` tracks whether the last input was from keyboard or mouse, affecting scroll behavior and hover sensitivity.

**Why it matters:** Allows the UI to behave differently based on input mode (e.g., keyboard scrolls aggressively, mouse hover scrolls conditionally).

**Upstream benefit:** Yes. More nuanced input handling.

**Classification:** Genuine improvement.

### 6.3 Granular Scroll-on-Hover Settings

**What:** Instead of a single `enableMouseHoverInSwitcher` toggle, local-usage adds:
- `scrollOnMouseHoverInSwitcher`
- `scrollHorizontallyOnHover`
- `scrollVerticallyOnHover`
- `enableEdgeScrollInSwitcher`
- `edgeScrollSpeed`
- `dynamicEdgeScrollSpeed`

**Why it matters:** Gives users fine-grained control over how mouse hover interacts with the switcher grid.

**Upstream benefit:** Debatable. More settings can be confusing. The core concept (separate scroll behavior for horizontal/vertical) is useful.

**Classification:** Mix of genuine improvement and personal preference.

---

## 7. Thumbnail and Cache Improvements

### 7.1 Live Preview Frame Capture on Panel Close

**What:** When the preview window hides, it iterates through all visible windows and saves the last live preview frame to the global window cache via `WindowUtil.updateCachedWindowImage()`.

**Why it matters:** Ensures the thumbnail shown next time the switcher opens is the most recent frame from the live preview, not a stale screenshot from minutes ago.

**Upstream benefit:** Yes. Better thumbnail freshness.

**Classification:** Genuine improvement.

### 7.2 Live Preview Frame Capture on Selection Change

**What:** When the user moves selection away from a window that had live preview (in `selectedWindowOnly` scope), the last frame is captured as the thumbnail.

**Why it matters:** Similar to above -- ensures thumbnails stay current as the user navigates.

**Upstream benefit:** Yes.

**Classification:** Genuine improvement.

### 7.3 `updateCachedWindowImage()` Function

**What:** A new static function on `WindowUtil` that updates a specific window's image in the desktop space cache.

**Why it matters:** Enables targeted cache updates without a full refresh cycle.

**Upstream benefit:** Yes.

**Classification:** Genuine improvement.

### 7.4 Screen Capture Cache Lifespan Default

**What:** Changed from 60 seconds (upstream) to 30 seconds.

**Why it matters:** Stale thumbnails are updated more frequently.

**Upstream benefit:** Minor. 30 vs 60 seconds is a preference.

**Classification:** Personal preference.

---

## 8. UI/UX Changes

### 8.1 Separate Dock and Switcher Header Settings

**What:** Upstream uses shared settings for dock preview and window switcher headers. Local-usage introduces separate settings for each context:
- `dockShowHeaderAppIcon`, `dockShowHeaderAppName` (dock preview)
- `switcherShowHeaderAppIcon`, `switcherShowHeaderAppName`, `switcherShowHeaderWindowTitle` (switcher)
- Separate visibility settings for each

**Why it matters:** Users may want different header configurations for dock hover (where the app context is obvious from the dock icon) vs. the window switcher (where identifying the app is critical).

**Upstream benefit:** Moderate. More flexibility, but upstream already has context-based settings with the `cmdTab*` prefix pattern.

**Classification:** Mix of genuine improvement and different design philosophy.

### 8.2 HeaderStyleModifier Refactor

**What:** The header view building code is refactored from three separate `case` blocks (default, shadowed, popover) with duplicated content into a single `headerContent()` function with a `HeaderStyleModifier` that only varies the padding/positioning.

**Why it matters:** Eliminates ~80 lines of duplicated header code. Changes to header content only need to be made once.

**Upstream benefit:** Yes. Code quality improvement.

**Classification:** Genuine improvement.

### 8.3 Glass Variant and Opacity Settings

**What:** New settings for glass material customization:
- `containerGlassVariant`, `previewCardGlassVariant`
- `containerOpacity`, `previewCardOpacity`
- `containerBorderOpacity`, `previewCardBorderOpacity`
- `showContainerBorder`, `showPreviewCardBorder`

**Why it matters:** Fine-grained visual customization of the macOS glass/blur materials.

**Upstream benefit:** Minor. Niche customization that most users won't touch.

**Classification:** Personal preference.

### 8.4 `disableActions` Flag on Preview Container

**What:** A `disableActions` flag prevents `WindowDismissalContainer` from being created in settings preview mode.

**Why it matters:** In the settings appearance preview, the dismissal container could interfere with real dock previews that appeared while settings was open.

**Upstream benefit:** Yes. Bug fix for settings preview interference.

**Classification:** Genuine bug fix.

### 8.5 Window Level Change

**What:** Window level changed from `.statusBar` to `.popUpMenu` when `raisedWindowLevel` is enabled.

**Why it matters:** `.popUpMenu` is above `.statusBar`, ensuring the preview window appears above menu bar items.

**Upstream benefit:** Debatable. May interfere with system popovers.

**Classification:** Personal preference.

### 8.6 P3 Color Space

**What:** Sets the preview window's color space to Display P3 if available.

**Why it matters:** Ensures wide-gamut colors in window thumbnails are displayed correctly on P3-capable displays.

**Upstream benefit:** Minor but correct for modern Macs.

**Classification:** Genuine improvement.

---

## 9. Dock Observer Changes

### 9.1 Async-First Dock Hover

**What:** Upstream shows cached windows immediately (synchronous) then refreshes with fresh windows via `mergeWindowsIfShowing()`. Local-usage only shows windows after the async `getActiveWindows()` call completes.

**Why it matters:** Upstream's approach is faster to show initial content. Local-usage's approach avoids potential visual jumps from window merging but adds latency to first appearance.

**Upstream benefit:** No. Upstream's approach (show cached, then refresh) is better UX.

**Classification:** Regression / personal preference. Upstream pattern is superior.

### 9.2 Removed `mergeWindowsIfShowing()`

**What:** The `mergeWindows()` and `mergeWindowsIfShowing()` methods on `PreviewStateCoordinator` and `SharedPreviewWindowCoordinator` are removed.

**Why it matters:** These methods provided seamless window list updates while the preview was visible. Without them, the preview must be recreated entirely to show updated windows.

**Upstream benefit:** No. This is a downgrade.

**Classification:** Regression. Upstream's merge pattern is more sophisticated and provides better UX.

### 9.3 Removed Event Tap Health Check

**What:** Upstream has a `removeEventTap()` method and health checks that re-create the event tap if it becomes disabled. Local-usage has simpler event tap cleanup.

**Why it matters:** Event taps can become disabled by the system. Upstream's health check pattern is more resilient.

**Upstream benefit:** N/A. Upstream is better here.

**Classification:** Regression.

### 9.4 Removed Dock List AX Subscription Validation

**What:** Upstream validates that the subscribed dock list AX element is still valid and resets if the dock rebuilds its UI. Local-usage removes this check.

**Upstream benefit:** N/A. Upstream is more robust.

**Classification:** Regression.

### 9.5 Hide Preview on Right-Click

**What:** Local-usage hides the preview window when right-clicking a dock icon (to show the context menu).

**Upstream benefit:** Yes, this is a good UX improvement. Upstream handles this differently.

**Classification:** Genuine improvement.

---

## 10. Marquee Text Changes

### 10.1 Removed `greedy` Parameter

**What:** The `greedy` parameter is removed from `MarqueeText`. Upstream uses `greedy` to allow the marquee to expand to fill available width.

**Why it matters:** Without `greedy`, the marquee text always takes its natural width. This prevents card expansion caused by marquee text growing to fill available space.

**Upstream benefit:** Debatable. The `greedy` parameter serves a purpose in upstream's layout.

**Classification:** Bug fix (prevents card expansion) that may break other layouts.

### 10.2 Removed `fixedSize` from MarqueeText

**What:** Commit `3fa2b0c` removes `fixedSize` from `MarqueeText` to prevent card expansion.

**Why it matters:** `fixedSize` was causing preview cards to expand beyond their intended dimensions when text was long.

**Upstream benefit:** Yes, if the same bug exists upstream.

**Classification:** Genuine bug fix.

### 10.3 Width Calculation Changes

**What:** The `targetWidth` calculation in `TheMarquee` is simplified. When measured and not moving, it returns `contentSize.width`. When measured and moving, it returns `actualWidth`.

**Upstream benefit:** Minor. Different behavior for edge cases.

**Classification:** Bug fix.

---

## 11. Traffic Light Buttons Enhancements

### 11.1 Hover Effects and Tooltips

**What:** Traffic light buttons gain:
- Hover highlight overlay (`Color.black.opacity(0.25)`)
- Tooltip text on hover (e.g., "Quit application", "Close window")
- `disableButtonHoverEffects` setting per context
- `showTrafficLightTooltips` setting per context

**Why it matters:** Improves discoverability of traffic light button actions, especially for new users unfamiliar with the color coding.

**Upstream benefit:** Yes. Better UX for button discovery.

**Classification:** Genuine improvement.

### 11.2 `hiddenUntilHover` Visibility Mode

**What:** New visibility option for both `WindowTitleVisibility` and `TrafficLightButtonsVisibility` that completely hides the element until the parent window is hovered.

**Why it matters:** Provides a cleaner look than "dimmed until hover" for users who want minimal UI.

**Upstream benefit:** Yes. More visibility options.

**Classification:** Genuine improvement.

### 11.3 Context-Specific Settings

**What:** Traffic light button settings are split into dock-specific and switcher-specific versions (e.g., `dockDisableDockStyleTrafficLights` vs `switcherDisableDockStyleTrafficLights`).

**Why it matters:** Users can configure traffic lights differently for each context.

**Upstream benefit:** Moderate. Upstream already has some context splitting (`cmdTab*` prefix).

**Classification:** Mix of improvement and complexity.

### 11.4 `ContextTrafficLightButtonsSettingsView`

**What:** A reusable settings view component that takes bindings for context-specific traffic light settings, replacing the duplicated settings UI.

**Upstream benefit:** Yes. Better code reuse for settings UI.

**Classification:** Genuine improvement.

---

## 12. Window Activation and Focus

### 12.1 Simplified Window Bring-to-Front

**What:** Upstream uses a retry loop (3 attempts with 50ms delays) for `bringToFront()`. Local-usage removes the retry logic and uses a simpler sequence: deminimize if needed, unhide if needed, activate, set front process, raise.

**Why it matters:** The retry loop was masking underlying issues. The simpler version either works or doesn't, making failures more obvious.

**Upstream benefit:** Debatable. Retries handle transient failures. The simpler version may fail more often but is more predictable.

**Classification:** Design trade-off.

### 12.2 Removed `quitAppOnWindowClose` Feature

**What:** Upstream has a setting to quit an app when its last window is closed via the traffic light button. This is removed in local-usage.

**Why it matters:** The feature was causing issues with apps that have background processes.

**Upstream benefit:** No. The feature is useful for some users.

**Classification:** Personal preference.

### 12.3 Windowless App Activation

**What:** When a windowless app entry is activated, local-usage uses `app.activate()` which brings the app to the foreground. If the app creates a new window on activation, it appears naturally.

**Upstream benefit:** Yes, if windowless app detection is adopted.

**Classification:** Part of windowless app system.

---

## 13. Settings and Configuration Differences

### 13.1 Default Value Changes

| Setting | Upstream | Local-Usage | Notes |
|---------|----------|-------------|-------|
| `switcherMaxRows` | 8 | 2 | Local prefers fewer, wider rows |
| `enableMouseHoverInSwitcher` | true | false | Local disables mouse hover by default |
| `screenCaptureCacheLifespan` | 60s | 30s | Local refreshes more frequently |
| `useWidthBasedLayout` | N/A | true (new) | Width-based bin-packing |
| `layoutWidthPercentage` | N/A | 0.90 (new) | 90% of screen width |

### 13.2 Removed Settings

- `anchorDockPreviewPosition` -- dock preview anchoring
- `requireShiftTabToGoBack` -- Shift+Tab backward cycling
- `quitAppOnWindowClose` -- quit app on last window close
- `persistedWindowOrder` -- window order persistence
- `windowSwitcherScrollDirection` -- horizontal vs vertical scroll toggle
- `windowSwitcherHorizontalOffsetPercent` / `windowSwitcherVerticalOffsetPercent` -- manual position offset
- `windowSwitcherAnchorToTop` -- top-anchor toggle
- `enableShiftWindowSwitcherPlacement` -- shift placement
- `cmdTabAutoSelectFirstWindow` -- auto-select first window in Cmd+Tab
- `cmdTabCycleKey` / `cmdTabBackwardCycleKey` -- custom cycle keys
- `hideHoverContainerBackground` / `hideWidgetContainerBackground` -- replaced by opacity controls
- `useOpaquePreviewBackground` -- replaced by opacity controls
- `appAppearanceMode` -- app appearance override
- `includeHiddenWindowsInDockPreview` / `includeHiddenWindowsInCmdTab` -- separate hidden windows toggle per context
- `compactModeHideTrafficLights`
- Various `WindowTitlePosition` and `TrafficLightButtonsPosition` options removed
- `WindowTitleDisplayCondition` enum removed
- `showWindowTitle` / `windowTitlePosition` / `trafficLightButtonsPosition` for dock context
- Multiple `cmdTab*` appearance settings (replaced by unified settings)

### 13.3 Added Settings

- `useWidthBasedLayout`, `layoutWidthPercentage` -- bin-packing control
- `switcherMaxColumns` -- column limit
- `previewWindowSpacing` -- gap between previews
- `containerGlassVariant`, `previewCardGlassVariant` -- glass material
- `containerOpacity`, `previewCardOpacity` -- opacity controls
- `containerBorderOpacity`, `previewCardBorderOpacity`, `showContainerBorder`, `showPreviewCardBorder` -- border controls
- `scrollOnMouseHoverInSwitcher`, `scrollHorizontallyOnHover`, `scrollVerticallyOnHover` -- granular scroll
- `enableEdgeScrollInSwitcher`, `edgeScrollSpeed`, `dynamicEdgeScrollSpeed` -- edge scroll
- `showTabsAsWindows` -- show browser tabs as separate windows
- `switcherSwipeLeftAction`, `switcherSwipeRightAction` -- horizontal swipe gestures
- Per-context header/traffic light visibility settings (dock vs switcher)

---

## 14. Removed Features

### 14.1 Window Order Persistence

**What:** Upstream has `WindowOrderPersistence` that saves and restores window order across app launches. This is entirely removed in local-usage.

**Upstream benefit:** N/A. Upstream feature is useful.

**Classification:** Intentional removal (local prefers fresh ordering).

### 14.2 Window Merge System

**What:** Upstream's `mergeWindows()` / `mergeWindowsIfShowing()` system for seamlessly updating visible previews is removed.

**Classification:** Regression for dock preview UX.

### 14.3 `WidgetHoverContainer`

**What:** Upstream has a separate `WidgetHoverContainer.swift`. Local-usage does not have this file.

**Classification:** Feature divergence (upstream added this after the branch diverged).

### 14.4 ScriptCommands / CLI Support

**What:** Upstream has `ScriptCommands.swift` for CLI invocation with `DockDoor.sdef`. Local-usage removes this.

**Classification:** Feature not needed for personal use.

### 14.5 `expectedContentSize` Pre-Computation

**What:** Upstream pre-computes expected content size from dimensions map to avoid layout jitter during frame refresh. Local-usage removes this in favor of `fittingSize` caching.

**Classification:** Different approach to the same problem.

### 14.6 Operation Timeout Wrapper

**What:** Upstream's `withTimeout()` wrapper (10-second timeout for async operations) and `getShareableContent()` with timeout protection are removed. Local-usage calls `SCShareableContent` directly.

**Upstream benefit:** N/A. The timeout is a safety net.

**Classification:** Simplification with trade-off (no timeout protection).

### 14.7 Onboarding Window

**What:** Upstream has an `OnboardingWindow.swift` that local-usage doesn't include.

**Classification:** Upstream feature added after branch divergence.

### 14.8 Advanced Settings, Separate Appearance/Gesture Tabs

**What:** Upstream has split settings into more granular views (`AdvancedSettingsView.swift`, `Appearance/` subdirectory, `Gestures/` subdirectory). Local-usage has an older settings structure.

**Classification:** Upstream UI improvements not merged into local-usage.

---

## 15. New Files Only in Local-Usage

| File | Purpose |
|------|---------|
| `ElectronAppRegistry.swift` | Centralized Electron app detection |
| `WindowManagementConstants.swift` | Magic number elimination |
| `WindowlessAppDetectable.swift` | Protocol for windowless app detection |
| `TimeBasedCache.swift` | Generic time-based cache protocol and implementations |
| `IndexManaging.swift` | Protocol for unified index management |
| `WindowSwitcherStateManager.swift` | Separate state manager for switcher |
| `WindowPreviewSettingsCache.swift` | Settings snapshot caching |
| `SelectionState.swift` | Lightweight selection state |
| `CarbonHotkeyManager.swift` | Carbon-based hotkey handling |
| `Protocols/` directory | Protocol definitions |
| `FirstTimeViewInstructionsView.swift` | Custom onboarding instructions |

---

## 16. Summary and Recommendations

### Features Strongly Recommended for Upstream

1. **SelectionState separation** -- Fixes cursor disappearance and scroll blocking. Clean architectural improvement.
2. **Settings cache system** -- Eliminates thousands of unnecessary KVO subscriptions per preview show.
3. **NSHostingView reuse** -- 50-70ms performance gain on repeated activations.
4. **Image count in cache keys** -- Fixes stale dimension caching when thumbnails load asynchronously.
5. **First-activation sizing fix** -- Fixes vertical clipping with `layoutSubtreeIfNeeded()` + deferred correction.
6. **Header code deduplication** -- Eliminates ~80 lines of duplicated header view code.
7. **Traffic light tooltips and hover effects** -- Better UX for button discovery.

### Features Worth Considering for Upstream

1. **Width-based bin-packing layout** -- Better space utilization, but a significant change to the layout system.
2. **Windowless app detection** -- Highly useful for Electron app users, but adds complexity.
3. **ElectronAppRegistry** -- Good centralization, but the hardcoded list needs ongoing maintenance.
4. **Synchronous switcher initialization** -- Faster activation, but removes the delay that helps with window discovery.
5. **CATransaction for instant UI** -- Prevents animation artifacts.

### Features That Are Personal Preferences

1. Glass variant and opacity settings
2. Granular scroll-on-hover settings (6 settings for something upstream handles with 2)
3. Default value changes (switcherMaxRows=2, screenCaptureCacheLifespan=30)
4. P3 color space (correct but edge-case benefit)

### Regressions to Avoid

1. **Removing `mergeWindowsIfShowing()`** -- Upstream's merge pattern provides better dock preview UX.
2. **Removing event tap health checks** -- Upstream's resilience is valuable.
3. **Removing dock list AX subscription validation** -- Upstream handles dock UI rebuilds.
4. **Removing operation timeout wrappers** -- Safety net for hung operations.
5. **Async-only dock hover** -- Upstream's "show cached, then refresh" is faster.
6. **VStack instead of LazyVStack** -- May cause memory issues with many windows.
