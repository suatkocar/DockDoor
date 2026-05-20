# UX and Settings Comparison: Upstream vs Local Fork

**Date:** 2026-03-09
**Upstream:** ejbills/DockDoor (main branch, latest)
**Local Fork:** local-usage branch

---

## Table of Contents

1. [Settings Organization (Tabs & Structure)](#1-settings-organization)
2. [Defaults Keys: Upstream Only](#2-defaults-keys-upstream-only)
3. [Defaults Keys: Local Fork Only](#3-defaults-keys-local-fork-only)
4. [Default Value Differences](#4-default-value-differences)
5. [Enum/Type Differences](#5-enumtype-differences)
6. [UX Feature Differences](#6-ux-feature-differences)
7. [Visual/Design Differences](#7-visualdesign-differences)
8. [Architecture Differences](#8-architecture-differences)
9. [Sync Priority Summary](#9-sync-priority-summary)

---

## 1. Settings Organization

### Upstream Settings Tabs (10 tabs, grouped in sections)

```
General
Features:
  - Dock Previews        (dedicated page)
  - Window Switcher      (dedicated page)
  - Cmd+Tab              (dedicated page)
Customization:
  - Appearance           (sub-sections: WindowSizeSettings, GeneralAppearance, CompactMode, AdvancedAppearance)
  - Gestures & Keybinds  (sub-sections: DockScroll, DockPreviewGestures, GestureSettings, MouseActions, CmdKeyShortcuts, WindowSwitcherKeybind)
  - Filters
  - Widgets
System:
  - Advanced             (Performance Tuning, Preview Quality, Live Preview)
  - Support
```

### Local Fork Settings Tabs (6 tabs, flat list)

```
General
Appearance       (monolithic single view with everything inline + live preview panes)
Gestures & Keybinds
Filters
Widgets
Support
```

### Analysis

| Aspect | Upstream | Local Fork | Better |
|--------|----------|------------|--------|
| Feature-specific settings | Dedicated Dock/Switcher/CmdTab pages | All mixed into General | Upstream |
| Settings discoverability | Section headers in sidebar | Flat list | Upstream |
| Appearance settings | Split into sub-component files | Single monolithic file with live preview | Local fork (live preview), Upstream (file organization) |
| Advanced/Performance settings | Dedicated Advanced tab | Embedded in General tab | Upstream |
| Settings window resizable | Yes (.resizable style mask) | No (no .resizable in style mask) | Upstream |
| Settings window min size | 750x400 | None set | Upstream |
| SettingsView column width | min: 700, ideal: 700 | min: 700, ideal: 700 | Same |
| Window release policy | isReleasedWhenClosed = true | isReleasedWhenClosed = false | Minor (upstream prevents stale references) |

**Priority: HIGH** - The upstream's 10-tab organization with dedicated feature pages is significantly more discoverable and maintainable than the local fork's 6-tab flat structure.

---

## 2. Defaults Keys: Upstream Only

These keys exist in upstream but NOT in the local fork:

### Dock Behavior
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `anchorDockPreviewPosition` | Bool | true | Keeps preview pinned where dock icon was when first hovered, preventing jumps during auto-hide | HIGH |
| `quitAppOnWindowClose` | Bool | false | Quit app when closing its last window from preview (Swift Quit replacement) | MEDIUM |
| `requireShiftTabToGoBack` | Bool | false | Require Shift+Tab (not Shift alone) to go backward in switcher | LOW |

### Cmd+Tab Enhancement
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `cmdTabAutoSelectFirstWindow` | Bool | false | Auto-highlight first window preview on Cmd+Tab open | MEDIUM |
| `cmdTabCycleKey` | UInt16 | kVK_ANSI_A | Custom key for cycling forward in Cmd+Tab | MEDIUM |
| `cmdTabBackwardCycleKey` | UInt16 | kVK_ANSI_Grave | Custom key for cycling backward in Cmd+Tab | MEDIUM |

### Cmd+Tab Appearance (Full Per-Feature Customization)
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `cmdTabShowAppName` | Bool | true | Show app header in Cmd+Tab | HIGH |
| `cmdTabAppNameStyle` | AppNameStyle | .default | App header style in Cmd+Tab | HIGH |
| `cmdTabShowAppIconOnly` | Bool | false | App icon only in Cmd+Tab | MEDIUM |
| `cmdTabShowWindowTitle` | Bool | true | Window title in Cmd+Tab | HIGH |
| `cmdTabWindowTitleVisibility` | WindowTitleVisibility | .alwaysVisible | Title visibility in Cmd+Tab | HIGH |
| `cmdTabWindowTitlePosition` | WindowTitlePosition | .bottomLeft | Title position in Cmd+Tab | MEDIUM |
| `cmdTabTrafficLightButtonsVisibility` | TrafficLightButtonsVisibility | .dimmedOnPreviewHover | Traffic lights in Cmd+Tab | HIGH |
| `cmdTabTrafficLightButtonsPosition` | TrafficLightButtonsPosition | .topLeft | Traffic light position in Cmd+Tab | MEDIUM |
| `cmdTabEnabledTrafficLightButtons` | Set<WindowAction> | [quit,close,minimize,toggleFullScreen] | Enabled buttons in Cmd+Tab | HIGH |
| `cmdTabUseMonochromeTrafficLights` | Bool | false | Monochrome traffic lights in Cmd+Tab | LOW |
| `cmdTabControlPosition` | WindowSwitcherControlPosition | .topTrailing | Control bar position in Cmd+Tab | MEDIUM |
| `cmdTabUseEmbeddedDockPreviewElements` | Bool | false | Embed controls in Cmd+Tab frames | MEDIUM |
| `cmdTabDisableDockStyleTrafficLights` | Bool | false | Disable pill styling on Cmd+Tab traffic lights | LOW |
| `cmdTabDisableDockStyleTitles` | Bool | false | Disable pill styling on Cmd+Tab titles | LOW |

### Window Display Settings (Per-Feature Granularity)
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `showWindowTitle` (dock) | Bool | true | Show window title in dock previews | HIGH |
| `showAppIconOnly` | Bool | false | Show only app icon | MEDIUM |
| `windowTitleDisplayCondition` | WindowTitleDisplayCondition | .all | Where to show titles (dock/switcher/both) | MEDIUM |
| `windowTitlePosition` | WindowTitlePosition | .bottomLeft | Title position in dock previews | MEDIUM |
| `trafficLightButtonsVisibility` | TrafficLightButtonsVisibility | .dimmedOnPreviewHover | Traffic lights in dock | HIGH |
| `trafficLightButtonsPosition` | TrafficLightButtonsPosition | .topLeft | Traffic light position in dock | MEDIUM |
| `enabledTrafficLightButtons` | Set<WindowAction> | [quit,close,minimize,toggleFullScreen] | Enabled buttons in dock | HIGH |
| `useMonochromeTrafficLights` | Bool | false | Monochrome traffic lights in dock | LOW |
| `disableDockStyleTrafficLights` | Bool | false | Disable pill styling on dock traffic lights | LOW |
| `disableDockStyleTitles` | Bool | false | Disable pill styling on dock titles | LOW |
| `showAppName` (dock header) | Bool | true | Show dock preview app header | HIGH |
| `includeHiddenWindowsInDockPreview` | Bool | true | Hidden/minimized windows in dock | HIGH |
| `includeHiddenWindowsInCmdTab` | Bool | true | Hidden/minimized windows in Cmd+Tab | HIGH |
| `showWindowsFromCurrentSpaceOnlyInCmdTab` | Bool | false | Current space filter for Cmd+Tab | MEDIUM |
| `cmdTabSortOrder` | WindowPreviewSortOrder | .recentlyUsed | Sort order for Cmd+Tab | MEDIUM |

### Mouse/Hover Behavior
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `mouseHoverAutoScrollSpeed` | CGFloat | 4.0 | Speed of auto-scroll on mouse hover in switcher | LOW |

### Media Widget Granularity
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `dockIconMediaScrollBehavior` | DockIconMediaScrollBehavior | .adjustVolume | What scroll does on media dock icons | MEDIUM |
| `mediaWidgetScrollBehavior` | MediaWidgetScrollBehavior | .seekPlayback | What scroll does in media widget | MEDIUM |
| `mediaWidgetScrollDirection` | MediaWidgetScrollDirection | .vertical | Scroll direction for media widget | LOW |

### Appearance
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `hideHoverContainerBackground` | Bool | false | Remove container background from preview panels | MEDIUM |
| `hideWidgetContainerBackground` | Bool | false | Remove container background from widget panels | LOW |
| `useOpaquePreviewBackground` | Bool | false | Solid color instead of blurred/transparent background | MEDIUM |
| `appAppearanceMode` | AppAppearanceMode | .system | Light/Dark/System mode override | HIGH |

### Compact Mode
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `compactModeHideTrafficLights` | Bool | false | Hide close/minimize buttons in compact mode | MEDIUM |

### Window Switcher Scroll
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `windowSwitcherScrollDirection` | WindowSwitcherScrollDirection | .vertical | Horizontal vs vertical scroll in switcher | HIGH |

### Search
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `searchTriggerKey` | UInt16 | kVK_ANSI_Slash | Key that activates search in switcher | MEDIUM |

### Window Order Persistence
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `persistedWindowOrder` | [PersistedWindowEntry] | [] | Saves window order across app restarts | HIGH |

### Window Switcher Placement
| Key | Type | Default | Description | Sync Priority |
|-----|------|---------|-------------|---------------|
| `windowSwitcherHorizontalOffsetPercent` | CGFloat | 0 | Horizontal offset for switcher position | MEDIUM |
| `windowSwitcherVerticalOffsetPercent` | CGFloat | 0 | Vertical offset for switcher position | MEDIUM |
| `windowSwitcherAnchorToTop` | Bool | false | Anchor switcher to top edge | LOW |
| `enableShiftWindowSwitcherPlacement` | Bool | false | Enable offset position controls | MEDIUM |

---

## 3. Defaults Keys: Local Fork Only

These keys exist in the local fork but NOT in upstream:

### Liquid Glass Fine-Tuning
| Key | Type | Default | Description | Value |
|-----|------|---------|-------------|-------|
| `containerGlassVariant` | Int | 19 | NSGlassEffectView variant (0-19) for container | Unique local enhancement |
| `previewCardGlassVariant` | Int | 18 | NSGlassEffectView variant for preview cards | Unique local enhancement |
| `containerBorderOpacity` | CGFloat | 1.0 | Opacity for container border | Unique local enhancement |
| `previewCardBorderOpacity` | CGFloat | 1.0 | Opacity for preview card border | Unique local enhancement |
| `showContainerBorder` | Bool | true | Show/hide container border | Unique local enhancement |
| `showPreviewCardBorder` | Bool | true | Show/hide preview card border | Unique local enhancement |
| `containerOpacity` | CGFloat | 1.0 | Overall container opacity | Unique local enhancement |
| `previewCardOpacity` | CGFloat | 1.0 | Overall preview card opacity | Unique local enhancement |

### Edge Scrolling System
| Key | Type | Default | Description | Value |
|-----|------|---------|-------------|-------|
| `enableEdgeScrollInSwitcher` | Bool | true | Enable edge-based scrolling | Unique local enhancement |
| `edgeScrollSpeed` | CGFloat | 16.0 | Edge scroll speed | Unique local enhancement |
| `dynamicEdgeScrollSpeed` | Bool | true | Speed increases closer to edge | Unique local enhancement |
| `scrollOnMouseHoverInSwitcher` | Bool | true | Mouse hover triggers scroll | Unique local enhancement |
| `scrollHorizontallyOnHover` | Bool | true | Allow horizontal scroll on hover | Unique local enhancement |
| `scrollVerticallyOnHover` | Bool | true | Allow vertical scroll on hover | Unique local enhancement |

### Layout System
| Key | Type | Default | Description | Value |
|-----|------|---------|-------------|-------|
| `switcherMaxColumns` | Int | 6 | Max columns for window switcher | Unique local enhancement |
| `previewWindowSpacing` | CGFloat | 24 | Gap between preview windows | Unique local enhancement |
| `useWidthBasedLayout` | Bool | true | Width-based bin-packing layout | Unique local enhancement |
| `layoutWidthPercentage` | CGFloat | 0.90 | Screen width percentage for layout | Unique local enhancement |

### Tab Handling
| Key | Type | Default | Description | Value |
|-----|------|---------|-------------|-------|
| `showTabsAsWindows` | Bool | false | Show browser tabs as individual windows | Unique local enhancement |

### Embedded Mode Granularity (Dock)
| Key | Type | Default | Description | Value |
|-----|------|---------|-------------|-------|
| `useEmbeddedWindowSwitcherElements` | Bool | false | Embed controls in switcher frames | Unique local enhancement |
| `dockShowHeaderAppIcon` | Bool | true | Show app icon in dock header | Unique local enhancement |
| `dockShowHeaderAppName` | Bool | true | Show app name in dock header | Unique local enhancement |
| `dockShowWindowTitle` | Bool | true | Show window title in dock embedded mode | Unique local enhancement |
| `dockWindowTitleVisibility` | WindowTitleVisibility | .alwaysVisible | Title visibility in dock | Unique local enhancement |
| `dockTrafficLightButtonsVisibility` | TrafficLightButtonsVisibility | .dimmedOnPreviewHover | Traffic lights in dock | Unique local enhancement |
| `dockEnabledTrafficLightButtons` | Set<WindowAction> | [quit,close,minimize,toggleFullScreen] | Enabled buttons in dock | Unique local enhancement |
| `dockUseMonochromeTrafficLights` | Bool | false | Monochrome traffic lights | Unique local enhancement |
| `dockDisableDockStyleTrafficLights` | Bool | false | Disable pill styling | Unique local enhancement |
| `dockDisableDockStyleTitles` | Bool | false | Disable pill title styling | Unique local enhancement |
| `dockDisableButtonHoverEffects` | Bool | false | Disable button hover effects | Unique local enhancement |
| `dockShowTrafficLightTooltips` | Bool | true | Show tooltips on traffic lights | Unique local enhancement |

### Embedded Mode Granularity (Window Switcher)
| Key | Type | Default | Description | Value |
|-----|------|---------|-------------|-------|
| `switcherShowHeaderAppIcon` | Bool | true | Show app icon in switcher header | Unique local enhancement |
| `switcherShowHeaderAppName` | Bool | true | Show app name in switcher header | Unique local enhancement |
| `switcherShowHeaderWindowTitle` | Bool | true | Show window title in switcher header | Unique local enhancement |
| `switcherHeaderAppIconVisibility` | WindowTitleVisibility | .alwaysVisible | Header icon visibility | Unique local enhancement |
| `switcherHeaderAppNameVisibility` | WindowTitleVisibility | .alwaysVisible | Header name visibility | Unique local enhancement |
| `switcherHeaderTitleVisibility` | WindowTitleVisibility | .alwaysVisible | Header title visibility | Unique local enhancement |
| `switcherDisableButtonHoverEffects` | Bool | false | Disable button hover effects in switcher | Unique local enhancement |
| `switcherShowTrafficLightTooltips` | Bool | true | Show tooltips on switcher traffic lights | Unique local enhancement |

### Gesture Extensions
| Key | Type | Default | Description | Value |
|-----|------|---------|-------------|-------|
| `switcherSwipeLeftAction` | WindowAction | .none | Left swipe action in switcher | Unique local enhancement |
| `switcherSwipeRightAction` | WindowAction | .none | Right swipe action in switcher | Unique local enhancement |

---

## 4. Default Value Differences

Where both repos have the same key but different defaults:

| Key | Upstream Default | Local Fork Default | Better |
|-----|------------------|---------------------|--------|
| `screenCaptureCacheLifespan` | 30 | 60 | Upstream (30s better for freshness) |
| `enableMouseHoverInSwitcher` | true | false | Upstream (enabled by default is standard) |
| `switcherMaxRows` | 8 | 2 | Local fork (2 is more sensible for screen space) |
| `LivePreviewQuality.standard.maxDimension` | 640 | 720 | Local fork (higher quality by default) |
| `LivePreviewQuality.high.maxDimension` | 960 | 1440 | Local fork (higher quality) |
| `LivePreviewQuality.retina.maxDimension` | 1280 | 2560 | Local fork (higher quality) |

---

## 5. Enum/Type Differences

### WindowTitleVisibility

**Upstream (3 cases):**
```swift
case whenHoveringPreview
case alwaysVisible
```
(Only 2 effective values; `whenHoveringPreview` is the only non-always option.)

**Local Fork (5 cases):**
```swift
case whenHoveringPreview    // Legacy compatibility
case never                  // Never visible
case hiddenUntilHover       // When hovering over the preview
case dimmedUntilHover       // Dimmed until hover
case alwaysVisible
```

Analysis: Local fork has richer visibility options with `never`, `hiddenUntilHover`, and `dimmedUntilHover`. Also provides `visibleCases` and `headerCases` filtered arrays for appropriate UI contexts. **Local fork is better.**

### TrafficLightButtonsVisibility

**Upstream (4 cases):**
```swift
case never, dimmedOnPreviewHover, fullOpacityOnPreviewHover, alwaysVisible
```

**Local Fork (5 cases):**
```swift
case never, hiddenUntilHover, dimmedOnPreviewHover, fullOpacityOnPreviewHover, alwaysVisible
```

Analysis: Local fork adds `hiddenUntilHover` and provides a `visibleCases` filtered array. **Local fork is better.**

### WindowSwitcherControlPosition

**Upstream (12 cases):**
Includes 4 `parallel*` variants in addition to the 8 cases shared with local fork.

**Local Fork (8 cases):**
```swift
topLeading, topTrailing, bottomLeading, bottomTrailing,
diagonalTopLeftBottomRight, diagonalTopRightBottomLeft,
diagonalBottomLeftTopRight, diagonalBottomRightTopLeft
```

Analysis: Upstream provides more layout options with parallel positions. Also has computed properties (`showsOnTop`, `showsOnBottom`, `toolbarHeightOffset`, `topConfiguration`, `bottomConfiguration`). **Upstream is better.**

### Media Scroll Behavior

**Upstream:** Three separate enums:
- `DockIconMediaScrollBehavior` (adjustVolume / activateHide)
- `MediaWidgetScrollBehavior` (adjustVolume / seekPlayback)
- `MediaWidgetScrollDirection` (vertical / horizontal)

**Local Fork:** Single combined enum:
- `MediaScrollBehavior` (adjustVolume / activateHide)

Analysis: Upstream provides more granular control separating dock icon behavior from widget behavior. **Upstream is better.**

### Missing from Local Fork Entirely

- `WindowTitleDisplayCondition` enum (all / dockPreviewsOnly / windowSwitcherOnly)
- `WindowTitlePosition` enum (bottomLeft / bottomRight / topRight / topLeft)
- `TrafficLightButtonsPosition` enum (topLeft / topRight / bottomRight / bottomLeft)
- `WindowSwitcherScrollDirection` enum (horizontal / vertical)
- `AppAppearanceMode` enum (system / light / dark)
- `WindowOrderPersistence` struct and mechanism

---

## 6. UX Feature Differences

### 6.1 Window Switcher Behavior

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Instant window switcher | Yes | Yes | Same |
| Search in switcher | Yes (with configurable trigger key) | Yes (no configurable trigger key) | Upstream |
| Mouse hover selection | Yes (with auto-scroll speed setting) | Yes (with rich edge-scroll system) | Local fork |
| Edge scrolling | No | Yes (speed, dynamic acceleration, directional control) | Local fork |
| Release-to-select | Yes (`preventSwitcherHide`) | Yes (`preventSwitcherHide`) | Same |
| Start on second window | Yes (`useClassicWindowOrdering`) | Yes (`useClassicWindowOrdering`) | Same |
| Limit to frontmost app | Yes | Yes | Same |
| Current space filter | Yes | Yes | Same |
| Grouped apps | Yes (with AppPickerSheet) | Yes (with AppPickerSheet) | Same |
| Scroll direction | Configurable (H/V) | Not configurable (removed in local) | Upstream |
| Width-based layout | No | Yes (bin-packing algorithm) | Local fork |
| Max columns setting | No | Yes (`switcherMaxColumns`) | Local fork |
| Window spacing setting | No | Yes (`previewWindowSpacing`) | Local fork |
| Require Shift+Tab to go back | Yes | No | Upstream |
| Placement offset | Yes (horizontal/vertical percent, anchor-to-top) | No | Upstream |
| `WindowSwitcherStateManager` | No (inline in coordinator) | Yes (dedicated class with IndexManaging protocol) | Local fork (architecture) |
| `CarbonHotkeyManager` | No | Yes (Carbon-based hotkey handling) | Local fork |

### 6.2 Dock Preview Behavior

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Enable/disable dock previews | Yes (dedicated settings page) | Yes (in General settings) | Upstream |
| Anchor preview position | Yes (`anchorDockPreviewPosition`) | No | Upstream |
| Quit app on window close | Yes | No | Upstream (Swift Quit replacement) |
| Preview hover action delay | Yes | Yes | Same |
| Include hidden windows in dock | Yes (`includeHiddenWindowsInDockPreview`) | No (only `includeHiddenWindowsInSwitcher`) | Upstream |
| Group app instances | Yes | Yes | Same |
| Ignore apps with single window | Yes | Yes | Same |
| Keep preview on terminate | Yes | Yes | Same |
| Sort order per feature | Yes (dock/switcher/cmdTab separate) | Yes | Same |
| Buffer from dock | Yes (slider) | Yes (slider) | Same |

### 6.3 Cmd+Tab Behavior

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Enable Cmd+Tab enhancements | Yes | Yes | Same |
| Dedicated settings page | Yes (`CmdTabSettingsView`) | No (in General settings) | Upstream |
| Custom cycle keys | Yes (forward and backward key capture) | No | Upstream |
| Auto-select first window | Yes | No | Upstream |
| Include hidden windows | Yes (`includeHiddenWindowsInCmdTab`) | No | Upstream |
| Per-feature sort order | Yes (`cmdTabSortOrder`) | Yes | Same |
| Current space filter | Yes (`showWindowsFromCurrentSpaceOnlyInCmdTab`) | Yes | Same |
| Full appearance customization | Yes (all Cmd+Tab-specific appearance keys) | No | Upstream |

### 6.4 Search Functionality

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Search in window switcher | Yes | Yes | Same |
| Configurable trigger key | Yes (`searchTriggerKey`) | No | Upstream |
| Fuzzy search | Yes | Yes | Same |
| Search fuzziness level | Yes | Yes | Same |

### 6.5 Keyboard Navigation

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Arrow key navigation | Yes | Yes | Same |
| Cmd+key shortcuts (3 customizable) | Yes | Yes | Same |
| Alternate keybind mode | Yes | Yes | Same |
| Fullscreen app blacklist | Yes | Yes | Same |
| Require Shift+Tab for backward | Yes | No | Upstream |

### 6.6 Mouse Interaction

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Mouse hover selection | Yes (with speed control) | Yes (with granular edge scroll) | Local fork |
| Middle click action | Yes | Yes | Same |
| Cmd+right-click quit | Yes | Yes | Same |
| Dock icon click action | Yes (minimize/hide) | Yes (minimize/hide) | Same |
| Edge-triggered scrolling | No | Yes (dedicated system) | Local fork |
| Dynamic edge scroll speed | No | Yes | Local fork |

### 6.7 Gestures

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Dock preview gestures (2 directions) | Yes | Yes | Same |
| Switcher gestures (up/down) | Yes (2 directions) | Yes (4 directions: up/down/left/right) | Local fork |
| Aero Shake | Yes | Yes | Same |
| Gesture sensitivity | Yes | Yes | Same |
| Dock scroll gesture | Yes | Yes | Same |
| Media scroll behavior | Granular (3 separate settings) | Simple (1 combined setting) | Upstream |

---

## 7. Visual/Design Differences

### 7.1 Card Styling Options

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Uniform card radius | Yes | Yes | Same |
| Hide preview card background | Yes | Yes | Same |
| Hide hover container background | Yes | No | Upstream |
| Hide widget container background | Yes | No | Upstream |
| Preview card glass variant | No | Yes (0-19 slider) | Local fork |
| Container glass variant | No | Yes (0-19 slider) | Local fork |
| Preview card opacity | No | Yes (0-1 slider) | Local fork |
| Container opacity | No | Yes (0-1 slider) | Local fork |
| Container border toggle | No | Yes | Local fork |
| Preview card border toggle | No | Yes | Local fork |
| Container border opacity | No | Yes | Local fork |
| Preview card border opacity | No | Yes | Local fork |
| Use opaque preview background | Yes | No | Upstream |

### 7.2 Background/Opacity Options

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Selection opacity | Yes | Yes | Same |
| Unselected content opacity | Yes | Yes | Same |
| Hover highlight color | Yes (with reset button) | Yes (with reset button) | Same |
| Dock preview background opacity | Yes | Yes | Same |
| Opaque background option | Yes | No | Upstream |

### 7.3 Traffic Light Buttons

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Per-feature visibility | Yes (dock/switcher/cmdTab separate) | Yes (dock/switcher separate, no cmdTab) | Upstream |
| Enabled buttons checkboxes | Yes (with live preview) | Yes (with live preview) | Same |
| Monochrome option | Yes | Yes | Same |
| Disable dock styling | Yes | Yes | Same |
| Position customization | Yes (`TrafficLightButtonsPosition` enum) | No | Upstream |
| Disable button hover effects | No | Yes | Local fork |
| Show tooltips | No | Yes | Local fork |

### 7.4 Title/Header Display

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Title display condition (where) | Yes (`WindowTitleDisplayCondition`) | No (separate per-feature keys) | Different approaches |
| Title position | Yes (`WindowTitlePosition` with 4 positions) | No | Upstream |
| App header icon/name toggles | No (single showAppName toggle) | Yes (separate icon/name toggles per context) | Local fork |
| Header visibility per-element | No | Yes (switcherHeaderAppIconVisibility, etc.) | Local fork |
| Title marquee scrolling | Yes | Yes | Same |
| Minimized/hidden labels | Yes | Yes | Same |
| Dimmed-until-hover title visibility | No | Yes | Local fork |

### 7.5 Liquid Glass Support

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Enable/disable Liquid Glass | Yes | Yes | Same |
| Glass variant tuning (0-19) | No | Yes (container + preview card) | Local fork |
| Glass opacity control | No | Yes (container + preview card) | Local fork |
| Border controls | No | Yes (toggle + opacity for container and card) | Local fork |
| BlurView component | Not found (likely inline) | Yes (`BlurView.swift` with `GlassEffectView`) | Local fork |

### 7.6 Dark Mode / Appearance Mode

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| System/Light/Dark mode override | Yes (`AppAppearanceMode` enum with segmented picker) | No | Upstream |

### 7.7 Live Preview in Settings

| Feature | Upstream | Local Fork | Better |
|---------|----------|------------|--------|
| Settings live preview pane | No (settings are text/toggles only) | Yes (mock window previews with context switcher) | Local fork |
| Mock coordinators for preview | No | Yes (dock + switcher mock coordinators) | Local fork |
| Dynamic preview updates | No | Yes (changes reflect in real-time preview) | Local fork |

---

## 8. Architecture Differences

### 8.1 Performance Profiles (Local Fork Only)

The local fork has a `SettingsProfile` enum (Default/Snappy/Relaxed) that adjusts multiple performance settings at once:
- `hoverWindowOpenDelay`, `fadeOutDuration`, `tapEquivalentInterval`, `preventDockHide`

This does not exist in upstream. It provides a friendlier UX for users who want quick performance presets without understanding each individual setting.

### 8.2 WindowPreviewSettingsCache (Local Fork Only)

The local fork has `WindowPreviewSettingsCache` and `HoverContainerSettingsCache` structs that snapshot all relevant UserDefaults at preview-show time, avoiding repeated reads during render. This is a performance optimization not present in upstream.

### 8.3 WindowSwitcherStateManager (Local Fork Only)

The local fork extracts window switcher state management into a dedicated `WindowSwitcherStateManager` class conforming to `IndexManaging` protocol. This provides cleaner separation of concerns compared to upstream's inline approach.

### 8.4 CarbonHotkeyManager (Local Fork Only)

The local fork uses a `CarbonHotkeyManager` for hotkey handling, which may provide different behavior from upstream's approach.

### 8.5 Window Order Persistence (Upstream Only)

Upstream has `WindowOrderPersistence` which saves window order to UserDefaults and restores it across app restarts. This maintains window ordering consistency between sessions.

### 8.6 Settings File Organization

**Upstream:** Settings are split into many focused files:
- `Appearance/` subfolder with 8 files
- `Gestures/` subfolder with 7 files
- `Help/` subfolder with 5 files
- `Shared Components/` subfolder with 10 files
- Total: ~48 settings files

**Local Fork:** Settings are more monolithic:
- `AppearanceSettingsView.swift` is a single large file (~600+ lines)
- `MainSettingsView.swift` handles everything General/Performance/Advanced
- Total: ~21 settings files

---

## 9. Sync Priority Summary

### Critical (Must Sync) - HIGH

1. **Settings tab organization** - Adopt upstream's 10-tab structure with dedicated feature pages (Dock Previews, Window Switcher, Cmd+Tab, Advanced)
2. **`anchorDockPreviewPosition`** - Important UX fix for auto-hiding docks
3. **`persistedWindowOrder` + WindowOrderPersistence** - Window order survival across restarts
4. **`appAppearanceMode`** (System/Light/Dark) - Standard accessibility feature
5. **Per-feature hidden window includes** (`includeHiddenWindowsInDockPreview`, `includeHiddenWindowsInCmdTab`) - Upstream provides granular control
6. **Cmd+Tab appearance keys** - Full per-feature appearance customization
7. **`windowSwitcherScrollDirection`** - Horizontal vs vertical is a major UX choice
8. **`WindowSwitcherControlPosition` parallel variants** - More layout options

### Important - MEDIUM

9. **`quitAppOnWindowClose`** - Swift Quit replacement feature
10. **Cmd+Tab cycle key customization** (`cmdTabCycleKey`, `cmdTabBackwardCycleKey`, `cmdTabAutoSelectFirstWindow`)
11. **`searchTriggerKey`** - Configurable search activation key
12. **`hideHoverContainerBackground`**, **`hideWidgetContainerBackground`** - More hide options
13. **`useOpaquePreviewBackground`** - Accessibility feature
14. **Switcher placement offset** (`enableShiftWindowSwitcherPlacement`, horizontal/vertical offsets, anchor-to-top)
15. **`compactModeHideTrafficLights`** - Compact mode polish
16. **Media widget granular settings** (3 separate enums vs 1)

### Nice to Have - LOW

17. **`requireShiftTabToGoBack`** - Power user preference
18. **`mouseHoverAutoScrollSpeed`** - Mouse hover fine-tuning
19. **`WindowTitlePosition`** enum - Position customization
20. **`TrafficLightButtonsPosition`** enum - Position customization

### Local Fork Advantages to Preserve

When syncing, the following local fork innovations should be preserved:

1. **Liquid Glass fine-tuning** (glass variants, border controls, opacity sliders) - Not in upstream
2. **Edge scrolling system** (speed, dynamic acceleration, directional control) - Not in upstream
3. **Width-based layout system** (bin-packing, screen width percentage) - Not in upstream
4. **Live preview in settings** (mock coordinators, context switcher) - Not in upstream
5. **Performance profiles** (Default/Snappy/Relaxed presets) - Not in upstream
6. **WindowPreviewSettingsCache** performance optimization - Not in upstream
7. **WindowSwitcherStateManager** architecture - Not in upstream
8. **4-directional switcher gestures** (left/right in addition to up/down) - Not in upstream
9. **Granular header controls** (icon/name toggles, per-element visibility) - Not in upstream
10. **Button hover effects toggle** and **traffic light tooltips** - Not in upstream
11. **`showTabsAsWindows`** - Browser tab support not in upstream
12. **Extended `WindowTitleVisibility`** (never/hiddenUntilHover/dimmedUntilHover) - Richer than upstream
13. **Extended `TrafficLightButtonsVisibility`** (hiddenUntilHover) - Richer than upstream

---

## Appendix: Complete Defaults Key Inventory

### Keys in Both (with same defaults unless noted in Section 4)

```
previewWidth, previewHeight, lockAspectRatio, bufferFromDock, globalPaddingMultiplier,
hoverWindowOpenDelay, useDelayOnlyForInitialOpen, preventDockHide, preventSwitcherHide,
shouldHideOnDockItemClick, dockClickAction, enableCmdRightClickQuit,
enableDockScrollGesture, screenCaptureCacheLifespan*, windowProcessingDebounceInterval,
windowPreviewImageScale, windowImageCaptureQuality, enableLivePreview,
enableLivePreviewForDock, enableLivePreviewForWindowSwitcher, dockLivePreviewQuality,
dockLivePreviewFrameRate, windowSwitcherLivePreviewQuality,
windowSwitcherLivePreviewFrameRate, windowSwitcherLivePreviewScope,
livePreviewStreamKeepAlive, uniformCardRadius, allowDynamicImageSizing,
tapEquivalentInterval, fadeOutDuration, preventPreviewReentryDuringFadeOut,
inactivityTimeout, previewHoverAction, aeroShakeAction, showSpecialAppControls,
useEmbeddedMediaControls, useEmbeddedDockPreviewElements, showBigControlsWhenNoValidWindows,
enablePinning, showAnimations, gradientColorPalette, enableWindowSwitcher,
instantWindowSwitcher, enableDockPreviews, showWindowsFromCurrentSpaceOnly,
windowPreviewSortOrder, showWindowsFromCurrentSpaceOnlyInSwitcher,
windowSwitcherSortOrder, sortMinimizedToEnd, enableCmdTabEnhancements,
enableMouseHoverInSwitcher*, useClassicWindowOrdering, includeHiddenWindowsInSwitcher,
ignoreAppsWithSingleWindow, groupAppInstancesInDock, useLiquidGlass, showMenuBarIcon,
raisedWindowLevel, launched, Int64maskCommand, Int64maskControl, Int64maskAlternate,
UserKeybind, showAppName, appNameStyle, selectionOpacity, unselectedContentOpacity,
hoverHighlightColor, dockPreviewBackgroundOpacity, hidePreviewCardBackground,
showActiveWindowBorder, enableTitleMarquee, showMinimizedHiddenLabels,
switcherShowWindowTitle, switcherWindowTitleVisibility,
switcherTrafficLightButtonsVisibility, switcherEnabledTrafficLightButtons,
switcherUseMonochromeTrafficLights, switcherDisableDockStyleTrafficLights,
previewMaxColumns, previewMaxRows, switcherMaxRows*, windowSwitcherPlacementStrategy,
windowSwitcherControlPosition, dockPreviewControlPosition, pinnedScreenIdentifier,
limitSwitcherToFrontmostApp, fullscreenAppBlacklist, appNameFilters, windowTitleFilters,
groupedAppsInSwitcher, customAppDirectories, filteredCalendarIdentifiers,
hasSeenCmdTabFocusHint, disableImagePreview, debugMode, showActiveAppIndicator,
activeAppIndicatorColor, activeAppIndicatorAutoSize, activeAppIndicatorAutoLength,
activeAppIndicatorHeight, activeAppIndicatorOffset, activeAppIndicatorLength,
activeAppIndicatorShift, gestureSwipeThreshold, enableDockPreviewGestures,
dockSwipeTowardsDockAction, dockSwipeAwayFromDockAction, enableWindowSwitcherGestures,
switcherSwipeUpAction, switcherSwipeDownAction, middleClickAction, cmdShortcut1Key,
cmdShortcut1Action, cmdShortcut2Key, cmdShortcut2Action, cmdShortcut3Key,
cmdShortcut3Action, alternateKeybindKey, alternateKeybindMode, keepPreviewOnAppTerminate,
enableWindowSwitcherSearch, compactModeTitleFormat, compactModeItemSize,
windowSwitcherCompactThreshold, dockPreviewCompactThreshold, cmdTabCompactThreshold,
searchFuzziness
```

*Asterisk indicates different default value (see Section 4).
