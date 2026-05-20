# DockDoor Architecture Comparison: Upstream vs Local Fork

**Date:** 2026-03-09
**Upstream:** ejbills/DockDoor (main branch, latest)
**Local fork:** local-usage branch

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [File Structure Differences](#2-file-structure-differences)
3. [PreviewStateCoordinator Pattern](#3-previewstatecoordinator-pattern)
4. [SharedPreviewWindowCoordinator](#4-sharedpreviewwindowcoordinator)
5. [Window Image Sizing Calculations](#5-window-image-sizing-calculations)
6. [WindowPreview View Composition](#6-windowpreview-view-composition)
7. [Live Preview / ScreenCaptureKit Integration](#7-live-preview--screencapturekit-integration)
8. [Window Caching System (WindowUtil)](#8-window-caching-system-windowutil)
9. [Settings / Preferences Architecture](#9-settings--preferences-architecture)
10. [Layout Calculation System](#10-layout-calculation-system)
11. [Additional Local Fork Innovations](#11-additional-local-fork-innovations)
12. [Performance Implications Summary](#12-performance-implications-summary)
13. [Sync Risk Assessment](#13-sync-risk-assessment)

---

## 1. Executive Summary

The upstream and local fork have diverged significantly in their architectural approaches. Both have evolved since the fork point, but in different directions:

- **Upstream** has focused on **UI organization** (settings decomposition into feature-focused tabs, reusable settings components, new features like WindowOrderPersistence and ScriptCommands).
- **Local fork** has focused on **performance optimization** (eliminating ObservableObject from PreviewStateCoordinator, settings caching, bin-packing layout, computation caching, LRU eviction for live captures).

The changes are largely complementary but create significant merge conflicts in the shared core files. The local fork's performance-oriented changes represent genuine improvements that upstream would benefit from, while upstream's settings reorganization is a much-needed UI improvement that the local fork should adopt.

---

## 2. File Structure Differences

### Files only in upstream (not in local fork)

| File | Purpose |
|------|---------|
| `Components/KeyCaptureButton.swift` | Reusable key capture UI component |
| `Utilities/ScriptCommands.swift` | Script/automation commands |
| `Utilities/Window Management/WindowOrderPersistence.swift` | Persists window order across sessions |
| `Views/Hover Window/Shared Components/WidgetHoverContainer.swift` | Dedicated widget hover container |
| `Views/Intro/OnboardingWindow.swift` | Standalone onboarding window |
| `Views/Settings/AdvancedSettingsView.swift` | New Advanced settings tab |
| `Views/Settings/CmdTabSettingsView.swift` | Dedicated Cmd+Tab settings |
| `Views/Settings/DockPreviewsSettingsView.swift` | Dedicated Dock Previews settings |
| `Views/Settings/WindowSwitcherBehaviorSettingsView.swift` | Window Switcher behavior settings |
| `Views/Settings/Appearance/*.swift` (8 files) | Decomposed appearance sections |
| `Views/Settings/Gestures/*.swift` (7 files) | Decomposed gesture sections |
| `Views/Settings/Shared Components/Settings*.swift` (7 files) | Reusable settings components |

### Files only in local fork (not in upstream)

| File | Purpose |
|------|---------|
| `Utilities/CarbonHotkeyManager.swift` | Carbon-based hotkey manager |
| `Utilities/ElectronAppRegistry.swift` | Registry for Electron apps |
| `Utilities/IndexManaging.swift` | Index management protocol |
| `Utilities/Protocols/*.swift` (4 files) | Protocol decomposition layer |
| `Utilities/TimeBasedCache.swift` | Generic time-based caching |
| `Utilities/WindowlessAppDetectable.swift` | Windowless app detection |
| `Utilities/WindowManagementConstants.swift` | Centralized magic-number constants |
| `Utilities/WindowManaging.swift` | Window management protocol |
| `Utilities/WindowSwitcherStateManager.swift` | Window switcher state management |
| `Views/Hover Window/WindowPreview Supporting/SelectionState.swift` | Lightweight selection observable |
| `Views/Hover Window/WindowPreview Supporting/WindowPreviewSettingsCache.swift` | Settings snapshot cache |
| `Views/Intro/FirstTimeViewInstructionsView.swift` | Onboarding instructions view |

**Assessment:** Upstream has significantly more settings-related files (decomposed architecture), while local fork has more utility/protocol files (performance and abstraction layer).

---

## 3. PreviewStateCoordinator Pattern

This is the single most impactful architectural difference between the two codebases.

### Upstream: ObservableObject

```swift
// Upstream: PreviewStateCoordinator.swift
class PreviewStateCoordinator: ObservableObject {
    @Published var currIndex: Int = -1
    @Published var windowSwitcherActive: Bool = false
    @Published var hasMovedSinceOpen: Bool = false
    @Published var fullWindowPreviewActive: Bool = false
    @Published var windows: [WindowInfo] = []
    @Published var shouldScrollToIndex: Bool = true
    @Published var searchQuery: String = ""
    @Published var overallMaxPreviewDimension: CGPoint = .zero
    @Published var windowDimensionsMap: [Int: WindowPreviewHoverContainer.WindowDimensions] = [:]
    @Published var effectiveGridColumns: Int = 1
    @Published var effectiveGridRows: Int = 1
    @Published var expectedContentSize: CGSize = .zero
    @Published var frameRefreshRequestId: UUID?
    // ... keybind session tracking with @Published
}
```

- Uses `@ObservedObject` in `WindowPreviewHoverContainer`
- Every `@Published` property change triggers SwiftUI view updates
- Has `mergeWindows()` for smooth window list updates
- Publishes `frameRefreshRequestId` for frame refresh requests
- Publishes `effectiveGridColumns/Rows` and `expectedContentSize` for layout

### Local Fork: Plain class with SelectionState

```swift
// Local: PreviewStateCoordinator.swift
final class PreviewStateCoordinator {
    let selectionState = SelectionState()  // Separate lightweight ObservableObject

    var currIndex: Int {
        get { selectionState.currentIndex }
        set { selectionState.currentIndex = newValue }
    }

    var windowSwitcherActive: Bool = false  // NOT @Published
    var hasMovedSinceOpen: Bool = false      // NOT @Published
    var windows: [WindowInfo] = []           // NOT @Published
    // ...
    var previewSettings: WindowPreviewSettingsCache?
    var containerSettings: HoverContainerSettingsCache?
}
```

```swift
// Local: SelectionState.swift
final class SelectionState: ObservableObject {
    @Published var currentIndex: Int = -1
    @Published var shouldScrollToIndex: Bool = true
    @Published var lastInputWasKeyboard: Bool = true
}
```

**Key differences:**

| Aspect | Upstream | Local Fork |
|--------|----------|------------|
| Base class | `ObservableObject` | Plain `final class` |
| Published properties | 14+ `@Published` properties | Only 3 via `SelectionState` |
| View update triggers | Any property change triggers full view tree rebuild | Only selection changes trigger targeted updates |
| Settings access | Direct `Defaults[]` reads | Cached via `WindowPreviewSettingsCache` |
| Window list updates | `mergeWindows()` with smooth transitions | `refreshUI()` via SharedPreviewWindowCoordinator |
| Mock support | Via `mockPreviewActive` flag | Via `isMockCoordinator` flag |
| Layout info | Published grid columns/rows/expectedContentSize | Not stored (computed at use site) |
| Keybind session | `isKeybindSessionActive` tracking | Not present |

**Which is better?**

The local fork's approach is architecturally superior for performance. The upstream approach causes cascading re-renders whenever *any* of the 14+ published properties change -- including heavyweight changes like `windows` array mutations or dimension map updates. The local fork's separation means:

1. Selection changes (the most frequent operation during hover/keyboard navigation) only update `SelectionState`, not the entire coordinator.
2. Heavy state changes (window list, dimensions) use `SharedPreviewWindowCoordinator.refreshUI()` for explicit, batched updates rather than implicit SwiftUI observation.
3. Cursor disappearance bugs during hover (documented in local fork comments) are avoided because hover interactions don't recreate the view hierarchy.

**However**, the upstream has one feature the local fork lacks: `mergeWindows()`, which provides smooth window list transitions (preserving order, updating in place, appending new, removing stale). The local fork removes this in favor of full replacement via `setWindows()`, which can cause visual jumps.

**Performance verdict:** Local fork wins on render performance. Upstream wins on smooth window list transitions.

---

## 4. SharedPreviewWindowCoordinator

### Upstream

- Recreates `NSHostingView` on every `showWindow()` call
- No view caching -- allocates new hosting view each time
- Uses `fittingSize` computed on fresh view (expensive)
- Has `expectedContentSize` from coordinator for frame sizing
- Has `mergeWindowsIfShowing()` for live window list updates
- `refreshPanelFrameToFitContent()` listens to `frameRefreshRequestId` via Combine
- `pinnedWindows` is `[String: (window: NSWindow, info: PinnedWindowInfo)]`
- Has `anchoredDockItem` for dock position anchoring
- Has `currentDockPosition` tracking

### Local Fork

- **Cached hosting view** (`cachedHostingView: NSHostingView<AnyView>?`) -- reuses the same view
- **Cached window size** (`cachedWindowSize: CGSize?`) -- avoids `fittingSize` overhead
- Uses `AnyView` wrapping with `EmptyView()` when hiding to force view teardown
- `pendingShowWorkItem` for explicit work item cancellation
- `pinnedWindows` is simpler `[String: NSWindow]`
- `appName` is `private(set)` (better encapsulation)
- No `mergeWindowsIfShowing()` -- uses explicit `refreshUI()` instead
- No `anchoredDockItem` or `currentDockPosition`
- No `frameRefreshRequestId` Combine listener

**Key local fork additions:**

```swift
// Cached hosting view for instant display (eliminates ~50-70ms view recreation)
private var cachedHostingView: NSHostingView<AnyView>?

// Cached size for instant positioning (eliminates ~20-30ms fittingSize overhead)
private var cachedWindowSize: CGSize?
```

**Performance verdict:** The local fork's hosting view caching is a significant performance improvement (~70-100ms faster per show cycle). This directly impacts perceived responsiveness when hovering over dock icons.

**Missing from local fork:** The upstream's `mergeWindowsIfShowing()` + `refreshPanelFrameToFitContent()` system provides dynamic window list updates (windows appearing/disappearing while the preview is shown) with proper frame resizing. The local fork does not handle this case as gracefully.

---

## 5. Window Image Sizing Calculations

### Upstream: Extension on WindowPreviewHoverContainer

```swift
extension WindowPreviewHoverContainer {
    struct WindowDimensions { ... }
    static func calculateOverallMaxDimensions(...) -> CGPoint { ... }
    static func precomputeWindowDimensions(...) -> [Int: WindowDimensions] { ... }
    static func calculateEffectiveMaxColumnsAndRows(...) -> (maxColumns: Int, maxRows: Int) { ... }
    static func chunkArray(...) -> [[T]] { ... }
    static func navigateWindowSwitcher(...) -> Int { ... }
    static func navigateInGrid(...) -> Int { ... }
}
```

- Implemented as an extension on the view struct
- No computation caching
- Simple chunking: distributes items evenly across rows (ceiling division)
- `chunkArray` has `fillToLimit` parameter for vertical scroll mode
- `calculateEffectiveMaxColumnsAndRows` uses 0.75 screen factor
- No bin-packing support

### Local Fork: Standalone enum

```swift
enum WindowImageSizingCalculations {
    struct WindowDimensions { ... }
    static func calculateThumbnailSize(...) -> CGSize { ... }  // NEW: alt-tab-macos logic
    static func calculateOverallMaxDimensions(...) -> CGPoint { ... }
    static func precomputeWindowDimensions(...) -> [Int: WindowDimensions] { ... }
    static func calculateEffectiveMaxColumnsAndRows(...) -> (...) { ... }
    static func chunkArray(...) -> [[T]] { ... }
    static func createBinPackedChunks(...) -> [[Int]] { ... }  // NEW: bin-packing
    static func navigateWindowSwitcher(...) -> Int { ... }
    static func navigateInGrid(...) -> Int { ... }

    // Computation caches
    private static var overallMaxDimensionsCache: CGPoint?
    private static var precomputeCache: [Int: WindowDimensions]?
}
```

**Key local fork additions:**

1. **Standalone enum** instead of view extension -- better separation of concerns
2. **Computation caching** for both `calculateOverallMaxDimensions` and `precomputeWindowDimensions` with hash-based invalidation
3. **Bin-packing layout** (`createBinPackedChunks`) that packs windows into rows based on actual pixel widths rather than uniform column counts
4. **`calculateThumbnailSize`** using alt-tab-macos thumbnailSize logic for more natural sizing
5. **`WindowManagementConstants`** for centralized magic numbers
6. **`switcherMaxColumns`** parameter (upstream only has `switcherMaxRows`)
7. **`layoutWidthPercentage`** setting for user-configurable layout width
8. **`useWidthBasedLayout`** toggle for bin-packing vs column-based layout
9. Uses configurable `layoutWidthPercentage` (default 0.90) vs upstream's hardcoded 0.75 screen factor

**Chunking difference:**

```
Upstream chunkArray (9 items, maxColumns=5):
  Row 1: [1, 2, 3, 4, 5]  (ceiling division: ceil(9/2) = 5 per row)
  Row 2: [6, 7, 8, 9]

Local chunkArray (9 items, maxColumns=5):
  Row 1: [1, 2, 3, 4, 5]  (fill up to maxColumns)
  Row 2: [6, 7, 8, 9]

Local bin-packed (9 items, varying widths):
  Row 1: [wide1, narrow1, narrow2]  (fills to screen width)
  Row 2: [wide2, medium1]            (fills to screen width)
  Row 3: [narrow3, narrow4, medium2, narrow5]
```

**Assessment:** The local fork has clearly superior layout calculation. The bin-packing approach gives visually better results for mixed-aspect-ratio windows, and the computation caching eliminates redundant work. The standalone enum is better architecture than extending a View struct.

---

## 6. WindowPreview View Composition

### Upstream

```swift
struct WindowPreview: View {
    // 30+ @Default property wrappers reading from UserDefaults
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleVisibility) var windowTitleVisibility
    // ... 27 more @Default properties
    let dimensions: WindowPreviewHoverContainer.WindowDimensions
    var useLivePreview: Bool
}
```

- Reads 30+ settings directly from `UserDefaults` via `@Default` property wrappers
- Each `@Default` creates a Combine subscription
- Dimension type is `WindowPreviewHoverContainer.WindowDimensions` (non-optional)
- `useLivePreview` is a simple Bool passed from parent
- Has `showAppIconOnly` parameter

### Local Fork

```swift
struct WindowPreview: View {
    let settings: WindowPreviewSettingsCache?  // All settings pre-cached
    let dimensions: WindowImageSizingCalculations.WindowDimensions?  // Optional
    let disableActions: Bool
    var isEligibleForLivePreview: Bool = true

    // Computed properties read from cache, fall back to Defaults
    private var windowSwitcherControlPosition: WindowSwitcherControlPosition {
        settings?.windowSwitcherControlPosition ?? Defaults[.windowSwitcherControlPosition]
    }
    // ... similarly for all settings
}
```

**Key differences:**

| Aspect | Upstream | Local Fork |
|--------|----------|------------|
| Settings access | 30+ `@Default` subscriptions | Single `WindowPreviewSettingsCache` struct |
| Dimensions | Non-optional | Optional (handles missing gracefully) |
| Live preview control | `useLivePreview: Bool` | `isEligibleForLivePreview` + cached settings |
| Action control | N/A | `disableActions: Bool` for mock previews |
| Render cost | High (30+ Combine subscriptions per preview card) | Low (pure struct reads) |

**Performance impact:** In a window switcher showing 20 windows, the upstream creates 600+ Combine subscriptions just for settings in the WindowPreview views alone. The local fork creates 0 Combine subscriptions by reading from a cached struct. This is a significant memory and CPU difference.

---

## 7. Live Preview / ScreenCaptureKit Integration

### Upstream

```swift
struct LivePreviewImage: View {
    // Branches between cached and fresh modes based on keepAlive setting
    if keepAlive != 0 {
        LivePreviewImageCached(...)
    } else {
        LivePreviewImageFresh(...)
    }
}
```

- Two separate views: `LivePreviewImageCached` (uses `@ObservedObject`) and `LivePreviewImageFresh` (uses `@StateObject`)
- `LiveCaptureManager` has no concurrency limits
- No LRU eviction
- Uses `requestStop()` with delayed cleanup
- Pixel format: `kCVPixelFormatType_32BGRA` always
- Resolution calculation uses `backingScaleFactor` directly
- Has `getShareableContent()` via `WindowUtil` helper

### Local Fork

```swift
struct LivePreviewImage: View {
    @ObservedObject private var capture: WindowLiveCapture
    // Single view, always uses ObservedObject + manager caching
}
```

- Single view implementation (simpler)
- `LiveCaptureManager` has **LRU eviction** with `maxConcurrentStreams = 24`
- Tracks `accessOrder` for LRU eviction
- `getLastFrame()` for thumbnail updates when switching away from live preview
- `forceStopBlocking()` for guaranteed stream cleanup
- `isCancelled` flag for race condition prevention during async operations
- Uses `SCShareableContent.excludingDesktopWindows` directly (no helper)
- Adds `.interpolation(.high)` and `.antialiased(true)` to images
- Uses `filter.pointPixelScale` on macOS 14+ for accurate native resolution
- Supports `native` quality with `scalesToFit = false`
- HDR: uses `kCVPixelFormatType_ARGB2101010LEPacked` on macOS 15+ (10-bit color)
- Has generation tracking with `isCancelled` checks at async boundaries

**Performance and reliability verdict:** The local fork has significantly more robust live preview handling:
- LRU eviction prevents resource exhaustion with many windows
- Race condition prevention via `isCancelled` + generation checks
- Better image quality with interpolation hints and 10-bit color on macOS 15
- `forceStopBlocking()` ensures clean shutdown

---

## 8. Window Caching System (WindowUtil)

Both codebases share the same fundamental `WindowUtil` structure, but with differences:

### Upstream additions

- `WindowOrderPersistence` -- persists window access timestamps to UserDefaults, survives app restart
- `ScriptCommands` -- CLI/scripting interface
- `WindowFetchContext` enum -- differentiates dock vs cmd-tab settings

### Local fork additions

- `MockWindowProvider` class -- proper mock for windowless apps (upstream uses `MockPreviewWindow` in a different file)
- `TimeBasedCache` protocol -- generic caching abstraction
- `WindowManagementConstants` -- centralized constants
- `WindowSwitcherStateManager` -- dedicated state machine for switcher lifecycle
- `ElectronAppRegistry` -- registry for Electron app detection
- Protocol decomposition in `Utilities/Protocols/`

**Assessment:** Upstream has more features (persistence, scripting). Local fork has better abstractions (protocols, constants, state management).

---

## 9. Settings / Preferences Architecture

This is where the upstream has made the most significant structural improvements.

### Upstream Settings Structure

```
Views/Settings/
  SettingsView.swift           -- NavigationSplitView with 9 tabs
  MainSettingsView.swift
  DockPreviewsSettingsView.swift     -- NEW: Feature-focused
  WindowSwitcherBehaviorSettingsView.swift  -- NEW: Feature-focused
  CmdTabSettingsView.swift           -- NEW: Feature-focused
  AppearanceSettingsView.swift       -- Slimmed down, delegates to sections
  AdvancedSettingsView.swift         -- NEW: Advanced settings
  GesturesAndKeybindsSettingsView.swift
  FiltersSettingsView.swift
  WidgetSettingsView.swift
  SupportSettingsView.swift

  Appearance/
    GeneralAppearanceSection.swift
    WindowSizeSettingsSection.swift
    CompactModeSection.swift
    DockPreviewAppearanceSection.swift
    CmdTabAppearanceSection.swift
    WindowSwitcherAppearanceSection.swift
    EnabledButtonsCheckboxes.swift
    AdvancedAppearanceSection.swift

  Gestures/
    GestureSettingsSection.swift
    DockPreviewGesturesSection.swift
    DockScrollGestureSection.swift
    WindowSwitcherGesturesSection.swift
    WindowSwitcherKeybindSection.swift
    MouseActionsSection.swift
    CmdKeyShortcutsSection.swift

  Shared Components/
    SettingsGroup.swift            -- Reusable group container
    SettingsIcon.swift             -- Reusable icon component
    SettingsToggleRow.swift        -- Reusable toggle row
    SettingsSliderRow.swift        -- Reusable slider row
    SettingsPickerRow.swift        -- Reusable picker row
    SettingsLinkRow.swift          -- Reusable link row
    SettingsNote.swift             -- Reusable note component
    SupportLinksSection.swift      -- Support links
    SettingsIllustratedRow.swift
    SettingsIllustratedToggle.swift
```

Sidebar tabs: General, Dock Previews, Window Switcher, Cmd+Tab, Appearance, Gestures & Keybinds, Filters, Widgets, Advanced, Support

### Local Fork Settings Structure

```
Views/Settings/
  SettingsView.swift           -- NavigationSplitView with 6 tabs
  MainSettingsView.swift
  AppearanceSettingsView.swift -- Monolithic, all appearance in one view
  GesturesAndKeybindsSettingsView.swift
  FiltersSettingsView.swift
  WidgetSettingsView.swift
  SupportSettingsView.swift
  BaseSettingsView.swift
  WindowSwitcherSettingsView.swift
  GradientColorPaletteSettingsView.swift

  Shared Components/
    SettingsIllustratedRow.swift
    SettingsIllustratedToggle.swift
```

Sidebar tabs: General, Appearance, Gestures & Keybinds, Filters, Widgets, Support

### Comparison

| Aspect | Upstream | Local Fork |
|--------|----------|------------|
| Tab count | 9 (feature-focused) | 6 (broad categories) |
| File count | 35+ settings files | 14 settings files |
| Reusable components | 7 (SettingsGroup, Icon, Toggle, Slider, Picker, Link, Note) | 2 (IllustratedRow, IllustratedToggle) |
| Feature isolation | Dock, Switcher, CmdTab each have own tab | Mixed into Appearance/General |
| Section decomposition | Appearance split into 8 section files | Monolithic AppearanceSettingsView |
| Component consistency | Unified SettingsToggleRow/SliderRow pattern | Mix of Toggle/sliderSetting |

**Assessment:** Upstream's settings architecture is substantially better organized:
- Feature-focused tabs make it easier for users to find relevant settings
- Reusable components ensure visual consistency
- Section decomposition keeps files manageable
- The local fork should adopt this structure

---

## 10. Layout Calculation System

### Upstream Layout

- `calculateEffectiveMaxColumnsAndRows` uses 75% screen width
- Simple column-based chunking
- `expectedContentSize` computed and published for dynamic frame sizing
- Vertical scroll mode supported via `fillToLimit` parameter in `chunkArray`
- Window switcher uses `windowSwitcherScrollDirection` setting

### Local Fork Layout

- `calculateEffectiveMaxColumnsAndRows` uses configurable `layoutWidthPercentage` (default 90%)
- **Bin-packing** for horizontal layouts (`createBinPackedChunks`)
- `useWidthBasedLayout` toggle: when true, ignores column limits and fills rows by pixel width
- `switcherMaxColumns` setting (upstream only has `switcherMaxRows`)
- `previewWindowSpacing` user-configurable gap between windows
- No `expectedContentSize` (no dynamic frame resizing)

**Bin-packing algorithm:**
```swift
static func createBinPackedChunks(
    windows: [WindowInfo],
    maxRowWidth: CGFloat,
    thickness: CGFloat,
    itemSpacing: CGFloat,
    maxColumns: Int,
    maxRows: Int
) -> [[Int]]
```

The bin-packing estimates each window's rendered width based on its aspect ratio, then packs windows into rows to maximize utilization. This gives much better results for mixed-aspect-ratio windows (e.g., wide browser + tall Slack + square terminal).

**Assessment:** The local fork's layout system is more sophisticated and produces better visual results. The bin-packing approach is genuinely innovative for this use case. However, the upstream's `expectedContentSize` system provides better dynamic resizing when windows appear/disappear.

---

## 11. Additional Local Fork Innovations

### Settings Caching (`WindowPreviewSettingsCache`)

The local fork introduces two settings cache structs:

```swift
struct WindowPreviewSettingsCache {
    // 30+ cached settings values
    static func current() -> WindowPreviewSettingsCache { ... }
}

struct HoverContainerSettingsCache {
    // 20+ cached settings values
    static func current() -> HoverContainerSettingsCache { ... }
}
```

These are created once when the preview window opens and passed through the view hierarchy. This eliminates hundreds of `UserDefaults` reads per render cycle.

### Richer Appearance Settings

The local fork has additional settings not in upstream:

| Setting | Purpose |
|---------|---------|
| `useEmbeddedWindowSwitcherElements` | Embedded elements in switcher mode |
| `dockShowHeaderAppIcon` / `dockShowHeaderAppName` | Dock header customization |
| `switcherShowHeaderAppIcon/Name/Title` | Switcher header customization |
| `switcherHeader*Visibility` | Per-element visibility in switcher header |
| `dockDisableButtonHoverEffects` | Disable hover effects on dock buttons |
| `dockShowTrafficLightTooltips` | Tooltip control |
| `containerGlassVariant` | Glass effect variant |
| `containerBorderOpacity` | Border opacity |
| `showContainerBorder` / `showPreviewCardBorder` | Border toggles |
| `previewCardOpacity` / `containerOpacity` | Opacity controls |
| `scrollOnMouseHoverInSwitcher` | Scroll behavior on hover |
| `scrollHorizontallyOnHover` / `scrollVerticallyOnHover` | Directional scroll control |
| `enableEdgeScrollInSwitcher` | Edge scrolling |
| `edgeScrollSpeed` / `dynamicEdgeScrollSpeed` | Edge scroll speed |
| `showTabsAsWindows` | Tab-as-window support |
| `switcherMaxColumns` | Column limit for switcher |
| `previewWindowSpacing` | Gap between preview windows |
| `useWidthBasedLayout` | Bin-packing layout toggle |
| `layoutWidthPercentage` | Screen width percentage for layout |
| `switcherSwipeLeftAction` / `switcherSwipeRightAction` | Additional gesture actions |

### WindowTitleVisibility Expansion

The local fork expands `WindowTitleVisibility` from 2 to 5 cases:

```
Upstream: whenHoveringPreview, alwaysVisible
Local:    whenHoveringPreview, never, hiddenUntilHover, dimmedUntilHover, alwaysVisible
```

Similarly, `TrafficLightButtonsVisibility` adds `hiddenUntilHover`.

### WindowSwitcherControlPosition

The local fork removes 4 parallel positions from `WindowSwitcherControlPosition`:

```
Upstream has (12 positions):
  topLeading, topTrailing, bottomLeading, bottomTrailing,
  diagonalTopLeftBottomRight, diagonalTopRightBottomLeft,
  diagonalBottomLeftTopRight, diagonalBottomRightTopLeft,
  parallelTopLeftBottomLeft, parallelTopRightBottomRight,
  parallelBottomLeftTopLeft, parallelBottomRightTopRight

Local has (8 positions):
  topLeading, topTrailing, bottomLeading, bottomTrailing,
  diagonalTopLeftBottomRight, diagonalTopRightBottomLeft,
  diagonalBottomLeftTopRight, diagonalBottomRightTopLeft
```

### LivePreviewQuality Resolution Differences

| Quality | Upstream maxDimension | Local Fork maxDimension |
|---------|----------------------|------------------------|
| standard | 640px | 720px |
| high | 960px | 1440px |
| retina | 1280px | 2560px |

The local fork provides significantly higher resolution options.

---

## 12. Performance Implications Summary

### Areas where Local Fork is faster

1. **PreviewStateCoordinator** -- Eliminating ObservableObject saves ~14 Combine subscriptions per coordinator, preventing cascading re-renders
2. **SelectionState separation** -- Only selection changes trigger SwiftUI updates, not window list or dimension changes
3. **WindowPreviewSettingsCache** -- Eliminates 30+ UserDefaults reads per WindowPreview render (potentially 600+ per switcher show)
4. **HoverContainerSettingsCache** -- Eliminates 20+ UserDefaults reads per container render
5. **Cached NSHostingView** -- Saves ~50-70ms per show by reusing the hosting view
6. **Cached window size** -- Saves ~20-30ms per show by avoiding fittingSize recalculation
7. **WindowImageSizingCalculations caching** -- Hash-based cache for dimension calculations
8. **LRU eviction for live captures** -- Prevents unbounded resource usage

### Areas where Upstream is faster/better

1. **mergeWindows()** -- Smooth window list transitions without full replacement
2. **frameRefreshRequestId + Combine** -- Dynamic frame resizing when window count changes
3. **expectedContentSize** -- Pre-computed content size avoids fittingSize recalculation on frame refresh
4. **WindowOrderPersistence** -- Window order survives app restart (feature, not performance)

### Estimated impact

For a typical use case (hovering over a dock icon with 5 windows):
- **Upstream:** ~120-180ms from hover to display (view creation + fittingSize + settings reads)
- **Local fork:** ~50-80ms from hover to display (cached view + cached size + cached settings)

For window switcher with 20 windows:
- **Upstream:** 600+ Combine subscriptions for settings, ~14 coordinator subscriptions
- **Local fork:** 0 settings subscriptions, 3 selection subscriptions

---

## 13. Sync Risk Assessment

### High-risk merge conflicts

1. **`PreviewStateCoordinator.swift`** -- Completely different architectures. Cannot be auto-merged.
2. **`SharedPreviewWindowCoordinator.swift`** -- Different caching strategies, different methods.
3. **`Window Image Sizing Calculations.swift`** -- Different location (extension vs enum), different implementations.
4. **`WindowPreview.swift`** -- Settings access pattern is fundamentally different.
5. **`WindowPreviewHoverContainer.swift`** -- Different parameters, different rendering approach.
6. **`consts.swift`** -- Many new settings in both codebases, different organization.
7. **`SettingsView.swift`** -- Different tab structure.

### Medium-risk merge conflicts

1. **`LiveWindowCapture.swift`** -- Similar structure but different details (LRU, pixel format).
2. **`BaseHoverContainer.swift`** -- Likely has settings cache references in local fork.
3. **`DockObserver.swift`** -- Likely different due to different coordinator APIs.
4. **`KeybindHelper.swift`** -- Upstream renamed to keybind system, local has CarbonHotkeyManager.

### Low-risk merge areas

1. **Calendar/Media views** -- Likely similar, minor changes.
2. **Extensions/** -- Mostly shared.
3. **ActiveAppIndicator/** -- Likely similar.
4. **FluidGradient/** -- Likely identical.

### Recommended sync strategy

1. **Adopt upstream settings architecture** (tabs, reusable components) -- but integrate settings caching
2. **Keep local PreviewStateCoordinator** approach -- it is architecturally superior
3. **Keep local WindowImageSizingCalculations** -- standalone enum + caching + bin-packing
4. **Keep local LiveWindowCapture** improvements -- LRU, race condition fixes, 10-bit color
5. **Adopt upstream mergeWindows()** -- integrate into local coordinator with refreshUI()
6. **Adopt upstream WindowOrderPersistence** -- useful feature
7. **Keep local WindowPreviewSettingsCache** -- clear performance win
8. **Merge consts.swift carefully** -- take all new settings from both, resolve naming conflicts

---

*Analysis based on actual source code comparison performed 2026-03-09.*
