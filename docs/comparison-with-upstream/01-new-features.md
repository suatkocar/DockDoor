# Upstream New Features Analysis

**Analysis Date:** 2026-03-09
**Baseline:** After PR #926 (suatkocar, merged Dec 18, 2025)
**Upstream Branch:** `ejbills/DockDoor:main`
**Comparison Range:** Dec 18, 2025 - Mar 9, 2026
**Total non-chore commits:** ~60
**Major releases in this period:** v1.29, v1.30, v1.30.1, v1.31, v1.31.1, v1.31.2, v1.32, v1.32.1

---

## Table of Contents

1. [Window Switcher Features](#1-window-switcher-features)
2. [Cmd+Tab Enhancements](#2-cmdtab-enhancements)
3. [Dock Preview Features](#3-dock-preview-features)
4. [Settings & UI Reorganization](#4-settings--ui-reorganization)
5. [AppleScript / CLI Automation](#5-applescript--cli-automation)
6. [Onboarding Redesign](#6-onboarding-redesign)
7. [Appearance & Visual Features](#7-appearance--visual-features)
8. [Performance & Stability (1.31 Mega PR)](#8-performance--stability-131-mega-pr)
9. [1.32 Mega PR Features](#9-132-mega-pr-features)
10. [Widget Improvements](#10-widget-improvements)
11. [Miscellaneous Features](#11-miscellaneous-features)
12. [Summary Table](#12-summary-table)

---

## 1. Window Switcher Features

### 1.1 Adjustable Window Switcher Position (PR #940)

**What it does:** Adds horizontal and vertical offset sliders (range -80% to +80%) that let the user reposition the window switcher on screen. Also adds a toggle to anchor the switcher to the top of the screen (so its top edge stays fixed regardless of how many windows are displayed), instead of centering vertically.

**Implementation:** New settings keys `windowSwitcherHorizontalOffsetPercent`, `windowSwitcherVerticalOffsetPercent`, `windowSwitcherAnchorToTop`, and `enableShiftWindowSwitcherPlacement` in `consts.swift`. The placement section is rendered in `WindowSwitcherBehaviorSettingsView.swift` with conditional slider UI that appears when offset is enabled.

**Significance:** Medium. Particularly useful for users with large or ultra-wide monitors who want the switcher closer to where they typically work.

**Relevant to local-usage?** Yes. This is a user-facing customization that improves usability on non-standard monitor setups. No conflicts expected.

**Files:** `DockDoor/consts.swift`, `DockDoor/Views/Settings/WindowSwitcherBehaviorSettingsView.swift`, `DockDoor/Views/Hover Window/Shared Components/SharedPreviewWindowCoordinator.swift`

---

### 1.2 Single-Entry App Grouping in Window Switcher (PR #941)

**What it does:** Adds the ability to configure specific apps (e.g., VS Code) to show up as just a single entry (most recent window) in the window switcher. When the user switches to active-app-only mode (e.g., Cmd+`), all windows of that app are shown. Configured via an app picker sheet in the Filters settings page.

**Implementation:** New `groupedAppsInSwitcher` setting stores an array of bundle IDs. An `AppPickerSheet` UI component lets users select apps. The window discovery logic filters windows for grouped apps to show only the most recent one.

**Significance:** Medium. Solves a real pain point for power users who have many windows of the same app (e.g., multiple VS Code projects).

**Relevant to local-usage?** Yes. A quality-of-life improvement for users with many windows of the same app.

**Files:** `DockDoor/consts.swift`, `DockDoor/Views/Settings/FiltersSettingsView.swift`, `DockDoor/Utilities/Window Management/WindowDiscoveryShared.swift`

---

### 1.3 Improved Going-Back Behavior (PR #955)

**What it does:** Adds a new option (`requireShiftTabToGoBack`) that, when enabled, requires pressing Shift+Tab (not just Shift alone) to navigate backward in the window switcher. This makes the behavior consistent with native macOS and Windows Cmd+Tab behavior.

**Implementation:** The setting is a boolean toggle in `consts.swift`. The logic in `KeybindHelper.swift` checks this flag and conditionally requires that Tab is also pressed (not just the Shift modifier) before cycling backward.

**Significance:** Minor. A consistency improvement for users who expect macOS/Windows-native backward-cycle behavior.

**Relevant to local-usage?** Yes. Small but useful for users accustomed to standard OS behavior.

**Files:** `DockDoor/consts.swift`, `DockDoor/Utilities/KeybindHelper.swift`

---

### 1.4 Force Window Switcher Direction (Feb 6)

**What it does:** Allows the user to force the window switcher to scroll in a specific direction (horizontal or vertical) rather than having it determined automatically. This is controlled via `windowSwitcherScrollDirection` setting.

**Implementation:** New `WindowSwitcherScrollDirection` enum with `.horizontal` and `.vertical` cases. The `WindowPreviewHoverContainer` uses this to determine scroll axis and layout chunking. The window switcher now defaults to vertical scrolling.

**Significance:** Medium. Gives users control over the switcher's layout direction, which is especially helpful depending on monitor orientation and personal preference.

**Relevant to local-usage?** Yes. Layout customization that users may appreciate.

**Files:** `DockDoor/consts.swift`, `DockDoor/Views/Hover Window/WindowPreviewHoverContainer.swift`, `DockDoor/Views/Hover Window/WindowPreview Supporting/Window Image Sizing Calculations.swift`

---

### 1.5 Customizable Cycle Key and Search Trigger Key (Feb 6)

**What it does:** Allows the user to customize which key cycles Cmd+Tab previews (default: A) and which key triggers the window switcher search (default: /). Uses a new `KeyCaptureButton` component that lets users press a key to capture it.

**Implementation:** New `KeyCaptureButton.swift` component that monitors for keyDown events and captures the keyCode. New settings `cmdTabCycleKey`, `cmdTabBackwardCycleKey`, and `searchTriggerKey` in `consts.swift`.

**Significance:** Medium. Power users can remap the cycle and search keys to their preference.

**Relevant to local-usage?** Yes. Key customization is a common request.

**Files:** `DockDoor/Components/KeyCaptureButton.swift`, `DockDoor/consts.swift`, `DockDoor/Utilities/KeybindHelper.swift`, `DockDoor/Views/Settings/MainSettingsView.swift`

---

### 1.6 Window Order Persistence on Quit/Restart (PR #954)

**What it does:** Saves the recency order of windows when DockDoor quits, and restores it on the next launch. Supports "Recently used" and "Creation order (fixed)" sort orders. Uses window title + bundle ID as the matching key. Caps at 500 persisted entries.

**Implementation:** New `WindowOrderPersistence.swift` utility with `PersistedWindowEntry` struct (Codable, stores bundleIdentifier, windowTitle, lastAccessedTime, creationTime). Entries are saved to `Defaults[.persistedWindowOrder]` on quit and loaded on startup. Uses an in-memory cache for fast lookups.

**Significance:** Medium. Prevents loss of window ordering across restarts, which was a frustration for users who carefully arrange their workflow.

**Relevant to local-usage?** Yes. Improves the user experience after app restarts/updates.

**Files:** `DockDoor/Utilities/Window Management/WindowOrderPersistence.swift`, `DockDoor/consts.swift`, `DockDoor/AppDelegate.swift`

---

## 2. Cmd+Tab Enhancements

### 2.1 Auto-Select First Window in Cmd+Tab (Feb 18)

**What it does:** Adds a toggle (`cmdTabAutoSelectFirstWindow`) that, when enabled, automatically highlights the first window preview when Cmd+Tab is invoked. Without this, the user needs to press the cycle key to select the first window.

**Implementation:** Simple boolean toggle checked in `DockObserver+CmdTab.swift` to auto-select index 0 on switcher activation.

**Significance:** Minor. A nice-to-have for users who prefer immediate selection.

**Relevant to local-usage?** Yes. Small UX improvement.

**Files:** `DockDoor/consts.swift`, `DockDoor/Utilities/DockObserver+CmdTab.swift`, `DockDoor/Views/Settings/MainSettingsView.swift`

---

### 2.2 Hide Minimized/Hidden Windows in Dock & Cmd+Tab (Feb 18)

**What it does:** Adds separate toggles for hiding minimized/hidden windows in dock previews (`includeHiddenWindowsInDockPreview`) and Cmd+Tab (`includeHiddenWindowsInCmdTab`), in addition to the existing window switcher toggle. Previously, there was only a single toggle for the window switcher.

**Implementation:** Two new boolean settings in `consts.swift`. The filtering logic in `DockObserver.swift` and `DockObserver+CmdTab.swift` respects these per-feature toggles.

**Significance:** Medium. Users can now control hidden/minimized window visibility independently for each feature.

**Relevant to local-usage?** Yes. Granular control that power users will appreciate.

**Files:** `DockDoor/consts.swift`, `DockDoor/Utilities/DockObserver.swift`, `DockDoor/Utilities/DockObserver+CmdTab.swift`

---

### 2.3 Cmd+Tab Backward Navigation with Shift+Tab and Custom Key (Feb 22)

**What it does:** Adds Shift+Tab backward cycling in Cmd+Tab mode, plus a configurable backward cycle key (`cmdTabBackwardCycleKey`, default: ` backtick/grave). This is part of the "spaceID staleness" commit which bundles multiple features.

**Implementation:** The `KeybindHelper.swift` now handles both Shift+Tab for standard backward navigation and the custom backward cycle key. The `CmdTabSettingsView` displays a `KeyCaptureButton` for configuring the backward key.

**Significance:** Medium. Makes Cmd+Tab navigation more complete and consistent with OS conventions.

**Relevant to local-usage?** Yes. Better keyboard navigation.

**Files:** `DockDoor/consts.swift`, `DockDoor/Utilities/KeybindHelper.swift`, `DockDoor/Views/Settings/CmdTabSettingsView.swift`

---

### 2.4 Dedicated Cmd+Tab Settings View

**What it does:** As part of the settings reorganization (PR #1106), Cmd+Tab now has its own dedicated settings tab with sections for Configuration (cycle keys, space filtering, sort order, auto-select) and Appearance (per-feature title/control/traffic light settings).

**Implementation:** New `CmdTabSettingsView.swift` with feature-specific appearance settings (e.g., `cmdTabShowAppName`, `cmdTabShowWindowTitle`, `cmdTabWindowTitlePosition`, `cmdTabTrafficLightButtonsVisibility`, `cmdTabTrafficLightButtonsPosition`, etc.).

**Significance:** Medium. Part of the larger settings reorganization. Gives Cmd+Tab its own customization surface.

**Relevant to local-usage?** Yes. Needed to stay compatible with upstream settings architecture.

**Files:** `DockDoor/Views/Settings/CmdTabSettingsView.swift`, `DockDoor/consts.swift`

---

## 3. Dock Preview Features

### 3.1 Separate Background Hiding Checkboxes (Jan 17)

**What it does:** Splits the single "hide preview card background" toggle into three separate checkboxes: `hidePreviewCardBackground`, `hideHoverContainerBackground`, and `hideWidgetContainerBackground`. This gives users more granular control over which backgrounds are transparent.

**Implementation:** Three new boolean settings replace the old single toggle. The `BaseHoverContainer`, `CalendarFullView`, and `MediaControlsFullView` each check their respective setting.

**Significance:** Minor. Fine-grained visual customization.

**Relevant to local-usage?** Yes. Non-conflicting visual preference.

**Files:** `DockDoor/consts.swift`, `DockDoor/Views/Hover Window/Shared Components/BaseHoverContainer.swift`, `DockDoor/Views/Settings/Appearance/GeneralAppearanceSection.swift`

---

### 3.2 Anchor Dock Preview Position (1.32)

**What it does:** When the dock auto-hides instantly, the preview window would jump off-screen because subsequent AX queries returned the hidden icon position. This feature caches the dock icon frame on first display and reuses it for the lifetime of the preview session. Controlled via `anchorDockPreviewPosition` toggle in Advanced settings.

**Implementation:** The `SharedPreviewWindowCoordinator` now stores an `anchoredDockItem` (AXUIElement + CGRect) that captures the dock icon position on first hover. Subsequent position calculations reuse this cached frame instead of re-querying AX. This also serves as a duplicate-display guard by comparing element identity.

**Significance:** Medium-Major. Fixes a real usability issue with auto-hiding docks and prevents preview bounce.

**Relevant to local-usage?** Yes. Important fix/feature for auto-hide dock users.

**Files:** `DockDoor/consts.swift`, `DockDoor/Views/Hover Window/Shared Components/SharedPreviewWindowCoordinator.swift`, `DockDoor/Views/Settings/AdvancedSettingsView.swift`

---

### 3.3 Quit App on Window Close (1.32)

**What it does:** Adds a toggle (`quitAppOnWindowClose`) that makes the close (X) traffic light button in dock previews quit the entire app instead of just closing the window -- but only when it is the last window of that app. Serves as a built-in replacement for the third-party "Swift Quit" utility.

**Implementation:** Boolean setting in `consts.swift`. The close action handler checks the cached window count and, if it's the last window, sends a quit command instead of a close command.

**Significance:** Minor-Medium. Convenient for users who want apps to quit when their last window is closed (like Linux behavior).

**Relevant to local-usage?** Yes. Nice quality-of-life feature.

**Files:** `DockDoor/consts.swift`, `DockDoor/Views/Settings/DockPreviewsSettingsView.swift`

---

### 3.4 Ignore Apps with Single Window Moved to Dock Previews Tab

**What it does:** The `ignoreAppsWithSingleWindow` toggle was moved from a general settings area into the Dock Previews settings tab for better discoverability.

**Significance:** Minor. Organizational improvement.

**Relevant to local-usage?** Yes, as part of settings reorganization sync.

---

## 4. Settings & UI Reorganization

### 4.1 Reusable Settings Component Architecture (PR #962)

**What it does:** Extracts monolithic settings views into reusable components: `SettingsGroup`, `SettingsIcon`, `SettingsLinkRow`, `SettingsNote`, `SettingsPickerRow`, `SettingsSliderRow`, `SettingsToggleRow`, and `SupportLinksSection`. Also introduces per-feature appearance sections (`CmdTabAppearanceSection`, `DockPreviewAppearanceSection`, `WindowSwitcherAppearanceSection`, etc.).

**Implementation:** 31 files changed with 2,593 additions and 2,309 deletions. The `AppearanceSettingsView` was slimmed from a monolithic view to one that delegates to sub-sections. `GesturesAndKeybindsSettingsView` was similarly decomposed.

**Significance:** Major (architectural). Foundation for the later settings tab reorganization.

**Relevant to local-usage?** Yes. This is a prerequisite for many subsequent features. Merging this will be necessary to stay compatible with upstream.

**Files:** `DockDoor/Views/Settings/Shared Components/` (new directory), `DockDoor/Views/Settings/Appearance/` (new directory), `DockDoor/Views/Settings/Gestures/` (new directory)

---

### 4.2 Feature-Focused Settings Tabs (PR #1106)

**What it does:** Restructures the settings sidebar from a flat list (General, Appearance, Gestures, Filters, Widgets, Support) into grouped sections:
- **Features:** Dock Previews, Window Switcher, Cmd+Tab
- **Customization:** Appearance, Gestures & Keybinds, Filters, Widgets
- **System:** Advanced, Support

New dedicated views: `DockPreviewsSettingsView`, `WindowSwitcherBehaviorSettingsView`, `CmdTabSettingsView`, `AdvancedSettingsView`. `MainSettingsView` slimmed from ~930 lines to ~280 lines.

**Implementation:** 11 files changed with 1,013 additions and 949 deletions. Each feature now has its own settings tab with behavior and appearance sections combined.

**Significance:** Major (UX). Dramatically improves settings discoverability and organization.

**Relevant to local-usage?** Yes. This is the current upstream settings architecture. The local branch's settings views will need to be aligned with this structure.

**Files:** `DockDoor/Views/Settings/SettingsView.swift`, `DockDoor/Views/Settings/DockPreviewsSettingsView.swift`, `DockDoor/Views/Settings/WindowSwitcherBehaviorSettingsView.swift`, `DockDoor/Views/Settings/CmdTabSettingsView.swift`, `DockDoor/Views/Settings/AdvancedSettingsView.swift`, `DockDoor/Views/Settings/MainSettingsView.swift`

---

### 4.3 Illustrated Feature Toggles in Settings Headers

**What it does:** Each major feature tab (Dock Previews, Window Switcher, Cmd+Tab) now has an illustrated header with a toggle to enable/disable the feature, using `SettingsIllustratedToggle` with images from the asset catalog (`DockPreviews`, `WindowSwitcher`, `CmdTab`).

**Significance:** Minor. Visual polish for settings.

**Relevant to local-usage?** Yes. Part of the settings reorganization.

---

### 4.4 BaseSettingsView Wrapper

**What it does:** Introduces `BaseSettingsView` as a standardized wrapper for all settings tab content, providing consistent padding, scroll behavior, and layout.

**Significance:** Minor (architectural). Ensures visual consistency across all settings tabs.

**Relevant to local-usage?** Yes. Required for settings compatibility.

**Files:** `DockDoor/Views/Settings/BaseSettingsView.swift`

---

## 5. AppleScript / CLI Automation

### 5.1 AppleScript Scripting Dictionary (PR #986, PR #1041)

**What it does:** Adds a full AppleScript scripting dictionary (`DockDoor.sdef`) allowing external automation of DockDoor. Supported commands include:
- **Preview commands:** `show preview`, `hide preview`, `show switcher`
- **Query commands:** `list windows`, `list apps`, `get active window`
- **Window action commands:** `focus window`, `minimize window`, `close window`, `maximize window`, `hide window`, `toggle fullscreen`, `center window`
- **Window positioning:** `position window` (left, right, top, bottom, corners)
- **Data commands:** `get window`, `get windows` (includes base64 PNG preview images)
- **Help:** `get help`

**Implementation:** `DockDoor.sdef` defines the scripting dictionary. `ScriptCommands.swift` (640 lines) implements `DockDoorCommands` enum with all the command logic, app resolution (by name, bundle ID, or PID), window resolution, and position parsing. Each AppleScript command class (e.g., `ShowPreviewCommand`, `ListWindowsCommand`, `WindowActionCommand`) delegates to this shared logic. Results are returned as JSON strings.

**Significance:** Major. Enables external tools, scripts, and automation workflows to control DockDoor. This is a significant extensibility feature.

**Relevant to local-usage?** Yes. Opens up automation possibilities. The local-usage branch could leverage this for custom workflows.

**Files:** `DockDoor/DockDoor.sdef`, `DockDoor/Utilities/ScriptCommands.swift`, `DockDoor/Info.plist`

---

### 5.2 CLI Handler (PR #986)

**What it does:** Adds initial support for CLI access to DockDoor via URL scheme commands (`DockDoor/Utilities/CLIHandler.swift`). Note: This file was later removed from the upstream codebase (the URL scheme approach was kept via `URLCommandHandler.swift` instead).

**Implementation:** The URL command handler processes `dockdoor://` URL scheme commands for showing/hiding previews and other actions.

**Significance:** Medium. Complements the AppleScript support for automation.

**Relevant to local-usage?** Yes. Enables quick scripted interactions.

**Files:** `DockDoor/Utilities/URLCommandHandler.swift`

---

## 6. Onboarding Redesign

### 6.1 Cinematic Intro Sequence (PR #986)

**What it does:** Completely redesigns the first-time launch experience with a cinematic overlay that fades in/out. The new onboarding includes:
- A `CinematicOverlay` (NSPanel at screen-saver level) with smooth fade animations
- Tab-based intro flow: `FirstTimeIntroTabView` and `FirstTimePermissionsTabView`
- Custom app icon animation in `FirstTimeViewAppIcon.swift`
- Audio feedback (mouse-down.mp3, mouse-up.mp3 sounds)
- Sound effects via `AVFoundation`
- New asset images for each feature (CmdTab, DockPreviews, WindowSwitcher screenshots)

**Implementation:** 58 files changed (many are assets). The old `FirstTimeView.swift` was restructured into multiple tab views. `OnboardingWindow.swift` implements the cinematic overlay system.

**Significance:** Medium. Only affects new user experience; existing users won't see this. However, it represents a significant polish improvement for first impressions.

**Relevant to local-usage?** Partially. The onboarding redesign is nice but not critical for an existing user's fork. However, staying in sync with the file structure is valuable.

**Files:** `DockDoor/Views/Intro/OnboardingWindow.swift`, `DockDoor/Views/Intro/FirstTimeView.swift`, `DockDoor/Views/Intro/Tabs/`, `Assets/`

---

## 7. Appearance & Visual Features

### 7.1 Parallel Title and Controls in Window Previews (PR #977)

**What it does:** Adds 4 new title + traffic controls alignment options where title and controls are on the same edge (parallel) rather than opposite edges:
- Parallel - Title top left, controls bottom left
- Parallel - Title top right, controls bottom right
- Parallel - Title bottom left, controls top left
- Parallel - Title bottom right, controls top right

This extends the existing diagonal layout options (where title and controls are on opposite corners).

**Implementation:** New cases added to `WindowSwitcherControlPosition` enum: `parallelTopLeftBottomLeft`, `parallelTopRightBottomRight`, `parallelBottomLeftTopLeft`, `parallelBottomRightTopRight`. Each case defines `topConfiguration` and `bottomConfiguration` with `(isLeadingControls, showTitle, showControls)` tuples. Also adds computed properties `showsOnTop`, `showsOnBottom`, and `toolbarHeightOffset`.

**Significance:** Medium. Gives users more control over preview window layout aesthetics.

**Relevant to local-usage?** Yes. Visual customization improvement.

**Files:** `DockDoor/consts.swift`, `DockDoor/Views/Hover Window/WindowPreview Supporting/` files

---

### 7.2 Window Title Position Setting (New)

**What it does:** Adds a `WindowTitlePosition` enum with four positions (bottomLeft, bottomRight, topRight, topLeft) for controlling where the window title appears on preview cards. This can be configured separately for dock previews (`windowTitlePosition`) and Cmd+Tab (`cmdTabWindowTitlePosition`).

**Implementation:** New `WindowTitlePosition` enum in `consts.swift` with corresponding settings keys.

**Significance:** Minor. Extends the parallel layout feature with title positioning.

**Relevant to local-usage?** Yes. Part of the appearance system.

---

### 7.3 Traffic Light Buttons Position Setting (New)

**What it does:** Adds a `TrafficLightButtonsPosition` enum with four positions (topLeft, topRight, bottomRight, bottomLeft) for controlling where traffic light buttons appear on preview cards. Separate settings for dock previews and Cmd+Tab.

**Implementation:** New `TrafficLightButtonsPosition` enum in `consts.swift` with `trafficLightButtonsPosition` and `cmdTabTrafficLightButtonsPosition` keys.

**Significance:** Minor. Fine-grained control over traffic light placement.

**Relevant to local-usage?** Yes. Part of the appearance system.

---

### 7.4 Hide Traffic Lights in Compact Mode (PR #1066)

**What it does:** Adds a `compactModeHideTrafficLights` toggle in Settings > Appearance > Compact Mode that hides close/minimize/maximize buttons in compact (list) view, giving more room for window titles.

**Implementation:** Simple boolean setting, checked in `WindowPreviewCompact.swift` to conditionally hide traffic light buttons. 12 additions, 1 deletion across 3 files.

**Significance:** Minor. Small but useful for compact mode users.

**Relevant to local-usage?** Yes. Non-conflicting UX improvement.

**Files:** `DockDoor/consts.swift`, `DockDoor/Views/Settings/Appearance/CompactModeSection.swift`, `DockDoor/Views/Hover Window/WindowPreviewCompact.swift`

---

### 7.5 Opaque Preview Background Toggle (Feb 22)

**What it does:** Adds a `useOpaquePreviewBackground` toggle that renders preview card backgrounds with a solid opaque background instead of the translucent/glass effect.

**Implementation:** Boolean setting in `consts.swift`, applied in the BlurView component.

**Significance:** Minor. Visual preference option.

**Relevant to local-usage?** Yes. Accessibility improvement for users who find translucent backgrounds hard to read.

**Files:** `DockDoor/consts.swift`, `DockDoor/Components/BlurView.swift`, `DockDoor/Views/Settings/Appearance/GeneralAppearanceSection.swift`

---

### 7.6 Manual Dark/Light Mode Override (Feb 22)

**What it does:** Adds an `AppAppearanceMode` picker (System/Light/Dark) that lets users force DockDoor's appearance independent of the system setting.

**Implementation:** New `AppAppearanceMode` enum with `.system`, `.light`, `.dark` cases. The `applyAppearanceMode()` function in `SwiftUIUtils.swift` sets `NSApp.appearance` accordingly. Called on app launch from `AppDelegate`.

**Significance:** Minor. Useful for users who want DockDoor's theme to differ from their system theme.

**Relevant to local-usage?** Yes. Addresses a long-standing request (closes #466, #524).

**Files:** `DockDoor/consts.swift`, `DockDoor/Extensions/SwiftUIUtils.swift`, `DockDoor/AppDelegate.swift`, `DockDoor/Views/Settings/Appearance/AdvancedAppearanceSection.swift`

---

### 7.7 Fall Back to Compact Mode When Image Missing (Jan 9)

**What it does:** When a window preview image fails to capture (returns nil), the preview automatically falls back to compact mode (title-only view) instead of showing a blank or broken preview.

**Implementation:** Logic in `WindowPreview.swift` and `WindowPreviewHoverContainer.swift` checks for nil images and switches to compact rendering.

**Significance:** Minor-Medium. Improves resilience for apps that don't expose their windows to the screen capture API.

**Relevant to local-usage?** Yes. Robustness improvement.

**Files:** `DockDoor/Views/Hover Window/WindowPreview.swift`, `DockDoor/Views/Hover Window/WindowPreviewHoverContainer.swift`

---

### 7.8 Updated App Icon Assets (PR #971)

**What it does:** Adds an `AppIcon.icon` file for macOS 26 icon theming compatibility (via Icon Composer), plus updated icon variants in the asset catalog. The `.icon` file is added to the Xcode project (not Assets.xcassets) as required by Apple's new icon theming system.

**Implementation:** 16 files changed, mostly binary assets. The existing `Assets.xcassets/AppIcon` is kept as a fallback for older macOS versions.

**Significance:** Minor. Forward-compatibility with macOS 26.

**Relevant to local-usage?** Yes. Should be included for macOS 26 compatibility.

**Files:** `Assets/Assets.xcassets/AppIcon.appiconset/`, Xcode project file

---

### 7.9 Window Title Display Condition (New)

**What it does:** Adds a `WindowTitleDisplayCondition` enum that controls where window titles appear: everywhere ("Dock Previews & Window Switcher"), dock previews only, or window switcher only. This gives users the option to show titles in some contexts but not others.

**Implementation:** New enum in `consts.swift` with `windowTitleDisplayCondition` setting.

**Significance:** Minor. Fine-grained title visibility control.

**Relevant to local-usage?** Yes. Part of the appearance system.

---

### 7.10 Simplified Visibility Enums

**What it does:** The `WindowTitleVisibility` and `TrafficLightButtonsVisibility` enums have been simplified:
- `WindowTitleVisibility` reduced to just `.whenHoveringPreview` and `.alwaysVisible` (removed `.never`, `.hiddenUntilHover`, `.dimmedUntilHover`)
- `TrafficLightButtonsVisibility` removed `.hiddenUntilHover` (kept `.never`, `.dimmedOnPreviewHover`, `.fullOpacityOnPreviewHover`, `.alwaysVisible`)

**Significance:** Minor. Simplification that reduces complexity.

**Relevant to local-usage?** Yes. The local branch has the old expanded enums which will need to be updated.

---

## 8. Performance & Stability (1.31 Mega PR)

### PR #1041 - 46 files changed, 2,212 additions, 1,022 deletions

### 8.1 Non-Blocking Window Preview Loading

**What it does:** Window preview images are now loaded asynchronously with a cache-first approach. If a cached image exists, it's shown immediately while a fresh capture runs in the background.

**Significance:** Major. Prevents UI hangs when switching between windows.

**Relevant to local-usage?** Yes. Critical performance improvement.

---

### 8.2 AX Observer Off Main Thread

**What it does:** Moves accessibility observer work off the main thread to prevent UI hangs when the frontmost app has a heavy workload (closes #827).

**Significance:** Major. Fixes a class of UI freezes.

**Relevant to local-usage?** Yes. Essential stability fix.

---

### 8.3 AX Operation Timeouts

**What it does:** Adds timeout limits to AX operations via `AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.0)` to prevent hangs from unresponsive apps.

**Significance:** Medium. Prevents DockDoor from hanging when an app's accessibility API is unresponsive.

**Relevant to local-usage?** Yes. Stability improvement.

---

### 8.4 AX Observer Callback Debouncing

**What it does:** Adds debouncing to AX observer callbacks to prevent rapid-fire notifications from causing performance issues.

**Significance:** Medium. Performance improvement.

**Relevant to local-usage?** Yes.

---

### 8.5 Invalid AX Subscription Detection

**What it does:** Detects and removes invalid AX subscription elements that previously required a restart to fix (closes #1001).

**Significance:** Medium. Reduces the need for manual restarts.

**Relevant to local-usage?** Yes.

---

### 8.6 Window Switcher Animation Lag Fix

**What it does:** Fixes animation lag in the window switcher (closes #804).

**Significance:** Medium. UX improvement.

**Relevant to local-usage?** Yes.

---

### 8.7 AppleScript Migration (NSAppleScript to osascript)

**What it does:** Switches from `NSAppleScript` to `osascript` process for music preview queries, fixing silent crashes and music preview failures (closes #967).

**Significance:** Medium. Fixes music widget reliability.

**Relevant to local-usage?** Yes.

---

### 8.8 Media Widget Memory Leak Fix

**What it does:** Fixes memory leaks in the media widget and prevents osascript process pileup.

**Significance:** Medium. Prevents memory growth over time.

**Relevant to local-usage?** Yes.

---

### 8.9 Centralized Corner Radius System (CardRadius enum)

**What it does:** Introduces a `CardRadius` enum to centralize all corner radius values, replacing scattered hardcoded values.

**Significance:** Minor (architectural). Code quality improvement.

**Relevant to local-usage?** Yes.

---

### 8.10 Lazy Stacks for View Performance

**What it does:** Switches to `LazyVStack`/`LazyHStack` for preview containers to improve rendering performance with many windows.

**Significance:** Medium. Reduces memory usage and improves scrolling performance.

**Relevant to local-usage?** Yes.

---

### 8.11 Structured Concurrency (LimitedTaskGroup Replacement)

**What it does:** Replaces `LimitedTaskGroup` with Swift structured concurrency to prevent a crash.

**Significance:** Medium. Crash fix.

**Relevant to local-usage?** Yes.

---

### 8.12 Liquid Glass Dynamic Update Fix

**What it does:** Fixes liquid glass not updating its background dynamically (closes #1004).

**Significance:** Minor. Visual fix for macOS 26 users.

**Relevant to local-usage?** Yes.

---

## 9. 1.32 Mega PR Features

### PR #1123 - 33 files changed, 731 additions, 588 deletions

### 9.1 Dock Preview Anchoring to Initial Icon Position

(Covered in Section 3.2 above)

---

### 9.2 Quit App on Window Close Toggle

(Covered in Section 3.3 above)

---

### 9.3 WidgetHoverContainer Extraction

**What it does:** Extracts `WidgetHoverContainer` as a reusable component that deduplicates the identical regular/pinned boilerplate previously shared between `MediaControlsFullView` and `CalendarFullView` (98 lines).

**Significance:** Minor (architectural). Code deduplication.

**Relevant to local-usage?** Yes. Keeps widget views clean.

**Files:** `DockDoor/Views/Hover Window/Shared Components/WidgetHoverContainer.swift`

---

### 9.4 Configurable Cache Validation Timer

**What it does:** Changes the background cache validation timer from a hardcoded 30s to a configurable value (default 60s) via the `screenCaptureCacheLifespan` setting. Later, the periodic timer was removed entirely and replaced with a throttled cache refresh on keybind activation to stop the screen recording popup from appearing repeatedly.

**Significance:** Medium. Fixes the annoying screen recording notification issue.

**Relevant to local-usage?** Yes. Important fix for user experience.

---

### 9.5 Trackpad Swipe Tap Suppression

**What it does:** Suppresses tap gesture handler during and briefly after trackpad scrolling to prevent the hidden window toggle from firing on fast swipes. Uses configurable `gestureSwipeThreshold` from settings.

**Significance:** Minor. Input handling improvement.

**Relevant to local-usage?** Yes.

**Files:** `DockDoor/Views/Hover Window/WindowPreview Supporting/TrackpadGestureModifier.swift`

---

### 9.6 Window Switcher Vertical Scroll Default

**What it does:** Changes the default window switcher scroll direction to vertical, with configurable horizontal/vertical options. Cmd+Tab is forced to single horizontal row.

**Significance:** Medium. Changes the default layout behavior.

**Relevant to local-usage?** Yes. Layout change that users will notice.

---

### 9.7 Dynamic Panel Width Sizing

**What it does:** Computes actual per-window rendered dimensions in `precomputeWindowDimensions` instead of storing width=0. Calculates `expectedContentSize` from real dimensions to bypass unreliable lazy stack `fittingSize` measurement.

**Significance:** Medium. Fixes sizing accuracy for the preview panel.

**Relevant to local-usage?** Yes.

---

### 9.8 Sleep/Wake Recovery for AX Observers

**What it does:** Work-in-progress recovery for stale AX observers and event taps after system sleep/wake cycles.

**Significance:** Medium. Stability improvement.

**Relevant to local-usage?** Yes.

---

## 10. Widget Improvements

### 10.1 Better UX for Pinned Widgets (Jan 7)

**What it does:** Improves the pinned widget experience by refining `PinnableView.swift` and `PinnedWindowDelegate.swift`. Changes include better window positioning, improved show/hide behavior, and smoother interactions for pinned media/calendar widgets.

**Implementation:** 67 lines added/modified in `PinnableView.swift`, 83 lines in `PinnedWindowDelegate.swift`.

**Significance:** Minor. Polish for the pinned widget feature.

**Relevant to local-usage?** Yes. If using pinned widgets.

**Files:** `DockDoor/Views/Hover Window/WindowPreview Supporting/Pinnable/PinnableView.swift`, `DockDoor/Views/Hover Window/WindowPreview Supporting/Pinnable/PinnedWindowDelegate.swift`

---

### 10.2 Media Widget Scroll Direction and Auto-Scroll Speed (Dec 20)

**What it does:** Adds horizontal/vertical scroll direction option for the media widget and a configurable auto-scroll speed for mouse hover in the window switcher. New settings: `mediaWidgetScrollDirection` (vertical/horizontal) and `mouseHoverAutoScrollSpeed` (1-10, step 0.5).

**Implementation:** New `MediaWidgetScrollDirection` enum. The scroll modifier in `VolumeScrollModifier.swift` respects the direction setting. Settings UI in `WidgetSettingsView.swift`.

**Significance:** Minor. Media widget customization.

**Relevant to local-usage?** Yes.

**Files:** `DockDoor/consts.swift`, `DockDoor/Views/Hover Window/Special Hover Windows/Media/VolumeScrollModifier.swift`, `DockDoor/Views/Settings/WidgetSettingsView.swift`

---

### 10.3 Widget Spacing Scaling with Global Padding Multiplier (1.32)

**What it does:** `SharedHoverAppTitle` previously used hardcoded padding for the `.default` style which didn't scale at non-1.0x spacing values. Now uses `globalPadding` to match `WindowPreviewHoverContainer` behavior.

**Significance:** Minor. Consistency fix.

**Relevant to local-usage?** Yes.

---

## 11. Miscellaneous Features

### 11.1 Hide Minimized/Hidden Labels in Compact Mode (PR #963)

**What it does:** Hides the "minimized" and "hidden" labels in compact mode when the `showMinimizedHiddenLabels` option is disabled. Previously, these labels showed regardless of the setting when in compact mode.

**Implementation:** Single line addition in `WindowPreviewCompact.swift`.

**Significance:** Minor. Bug fix / consistency improvement.

**Relevant to local-usage?** Yes.

---

### 11.2 SpaceID Staleness Refresh (Feb 22)

**What it does:** Refreshes window spaceIDs on AX events (focus, move, minimize, hide/show). Previously, stale spaceIDs could cause windows to appear in the wrong space's preview or be incorrectly filtered.

**Implementation:** The `WindowManipulationObservers.swift` now refreshes spaceID on relevant AX callbacks. `WindowUtil.swift` also has logic to block windows with stale space IDs from entering the cache.

**Significance:** Medium. Fixes incorrect window-to-space association.

**Relevant to local-usage?** Yes. Important correctness fix.

**Files:** `DockDoor/Utilities/Window Management/WindowManipulationObservers.swift`, `DockDoor/Utilities/Window Management/WindowUtil.swift`

---

### 11.3 Media Scroll Behavior Split

**What it does:** The old `MediaScrollBehavior` enum (adjustVolume/activateHide) has been split into two separate enums: `DockIconMediaScrollBehavior` (for scrolling on the dock icon of media apps) and `MediaWidgetScrollBehavior` (adjustVolume/seekPlayback for the media widget). This allows different scroll behaviors for the dock icon vs. the widget.

**Significance:** Minor. More granular control.

**Relevant to local-usage?** Yes. Breaks the old `mediaScrollBehavior` setting key.

---

### 11.4 Reduced Live Preview Quality Defaults

**What it does:** Lowers the default live preview quality values to reduce performance impact:
- Standard: 720px -> 640px
- High: 1440px -> 960px
- Retina: 2560px -> 1280px

**Significance:** Minor. Performance optimization.

**Relevant to local-usage?** Yes. Affects the live preview stream feature that the local branch contributed.

---

### 11.5 Settings Keys Consolidation

**What it does:** Many separate dock/switcher-specific settings have been consolidated or removed:
- Removed: `dockShowHeaderAppIcon`, `dockShowHeaderAppName`, `switcherShowHeaderAppIcon`, `switcherShowHeaderAppName`, `switcherShowHeaderWindowTitle`, and associated visibility keys
- Removed: `useEmbeddedWindowSwitcherElements`, `showTabsAsWindows`, `useWidthBasedLayout`, `layoutWidthPercentage`
- Removed: glass variant/opacity keys (`containerGlassVariant`, `previewCardGlassVariant`, `containerBorderOpacity`, `previewCardBorderOpacity`, `showContainerBorder`, `showPreviewCardBorder`, `containerOpacity`, `previewCardOpacity`)
- Removed: edge scroll settings (`enableEdgeScrollInSwitcher`, `edgeScrollSpeed`, `dynamicEdgeScrollSpeed`, `scrollOnMouseHoverInSwitcher`, `scrollHorizontallyOnHover`, `scrollVerticallyOnHover`)
- Removed: switcher left/right gesture actions (`switcherSwipeLeftAction`, `switcherSwipeRightAction`)
- Removed: `switcherMaxColumns` (replaced by `switcherMaxRows` with vertical flow)
- Added unified settings: `showWindowTitle`, `showAppIconOnly`, `windowTitleDisplayCondition`, etc.

**Significance:** Medium (breaking). The local branch has many of these removed keys in its `consts.swift`. Syncing will require migrating away from them.

**Relevant to local-usage?** Yes. Critical to track for merge compatibility. The local branch's `consts.swift` has diverged significantly from upstream.

---

### 11.6 Liquid Glass Freeze Fix (Feb 21)

**What it does:** Fixes liquid glass rendering freezing after the window server marks a window as "no longer aware" on macOS 26.

**Significance:** Minor. macOS 26-specific fix.

**Relevant to local-usage?** Yes if targeting macOS 26.

---

### 11.7 Active App Indicator Fixes (PR #1051)

**What it does:** Fixes the active app indicator being shown in full-screen spaces and fixes indicator misalignment when the dock size changes (e.g., when an app is closed).

**Significance:** Minor. Bug fixes for the active app indicator feature.

**Relevant to local-usage?** Yes.

---

## 12. Summary Table

| # | Feature | PR/Commit | Significance | Benefit to local-usage? |
|---|---------|-----------|-------------|------------------------|
| 1.1 | Window Switcher position sliders | #940 | Medium | Yes |
| 1.2 | Single-entry app grouping | #941 | Medium | Yes |
| 1.3 | Shift+Tab to go back option | #955 | Minor | Yes |
| 1.4 | Force switcher direction | e6dc486 | Medium | Yes |
| 1.5 | Custom cycle/search keys | a98919a | Medium | Yes |
| 1.6 | Window order persistence | #954 | Medium | Yes |
| 2.1 | Auto-select first window | e167bd2 | Minor | Yes |
| 2.2 | Per-feature hidden window toggles | e167bd2 | Medium | Yes |
| 2.3 | Cmd+Tab backward nav key | 2162718 | Medium | Yes |
| 2.4 | Dedicated Cmd+Tab settings | #1106 | Medium | Yes |
| 3.1 | Separate background hiding | d9897a4 | Minor | Yes |
| 3.2 | Anchor dock preview position | #1123 | Medium-Major | Yes |
| 3.3 | Quit app on window close | #1123 | Minor-Medium | Yes |
| 4.1 | Reusable settings components | #962 | Major (arch) | Yes - prerequisite |
| 4.2 | Feature-focused settings tabs | #1106 | Major (UX) | Yes - essential |
| 5.1 | AppleScript automation | #1041 | Major | Yes |
| 5.2 | URL scheme CLI | #986 | Medium | Yes |
| 6.1 | Cinematic intro | #986 | Medium | Partially |
| 7.1 | Parallel title/controls | #977 | Medium | Yes |
| 7.4 | Hide traffic lights compact | #1066 | Minor | Yes |
| 7.5 | Opaque background toggle | 2162718 | Minor | Yes |
| 7.6 | Dark/light mode override | 2162718 | Minor | Yes |
| 7.7 | Compact mode fallback | 8dc8404 | Minor-Medium | Yes |
| 7.8 | Updated app icons (macOS 26) | #971 | Minor | Yes |
| 8.1 | Non-blocking preview loading | #1041 | Major | Yes - critical |
| 8.2 | AX observer off main thread | #1041 | Major | Yes - critical |
| 8.3 | AX operation timeouts | #1041 | Medium | Yes |
| 8.4 | AX callback debouncing | #1041 | Medium | Yes |
| 8.6 | Switcher animation lag fix | #1041 | Medium | Yes |
| 8.7 | osascript migration | #1041 | Medium | Yes |
| 8.8 | Media widget memory leak fix | #1041 | Medium | Yes |
| 8.10 | Lazy stacks | #1041 | Medium | Yes |
| 9.4 | Cache validation timer removal | #1123 | Medium | Yes |
| 9.5 | Trackpad swipe tap suppression | #1123 | Minor | Yes |
| 9.6 | Vertical scroll default | #1123 | Medium | Yes |
| 10.1 | Better pinned widget UX | aae1351 | Minor | Yes |
| 10.2 | Media widget scroll direction | e45e0e1 | Minor | Yes |
| 11.2 | SpaceID staleness refresh | 2162718 | Medium | Yes |
| 11.5 | Settings keys consolidation | Multiple | Medium (breaking) | Yes - critical for merge |

---

## Key Takeaways

### High-Priority Items for Merge

1. **Settings reorganization (PR #962 + PR #1106)** - The settings architecture has fundamentally changed. The local branch must align with the new structure (feature-focused tabs, reusable components, BaseSettingsView) to stay mergeable.

2. **1.31 performance overhaul (PR #1041)** - Contains critical stability fixes (AX off main thread, non-blocking preview loading, timeout limits, memory leak fixes). These should be merged as soon as possible.

3. **Settings keys consolidation** - Many settings keys used by the local branch have been removed or renamed in upstream. This will cause compile errors on merge and needs careful migration.

4. **AppleScript automation** - A major new extensibility feature that the local branch would benefit from for custom workflows.

### Merge Complexity Assessment

The upstream has undergone significant architectural changes since Dec 18, 2025:
- **`consts.swift`** has ~590 lines of diff (keys added, removed, renamed, enums changed)
- **Settings views** have been completely restructured into per-feature tabs
- **Several enums** have been simplified (visibility options reduced)
- **Glass/opacity settings** have been removed
- **Edge scroll settings** removed in favor of simpler auto-scroll speed
- **Window switcher layout** changed from column-based to row-based with vertical scroll default

The local branch's changes (primarily the live preview stream keep-alive feature from PR #926) should merge cleanly in isolation, but the surrounding code context has changed substantially. A rebase or careful merge will be needed.

### Recommendation

Sync with upstream main in stages:
1. First merge the settings architecture changes (#962, #1106) as they affect the most files
2. Then merge the 1.31 stability improvements (#1041)
3. Then merge the remaining individual features
4. Finally, re-apply any local-usage-specific changes on top
