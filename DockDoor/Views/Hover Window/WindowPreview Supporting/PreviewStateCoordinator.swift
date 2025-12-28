import Defaults
import SwiftUI

// Import WindowImageSizingCalculations for dimension calculations
// WindowImageSizingCalculations is defined in Window Image Sizing Calculations.swift

// Pure UI state container for window preview presentation
// ARCHITECTURE NOTE:
// - PreviewStateCoordinator itself is NOT an ObservableObject to prevent SwiftUI subscriptions
//   from interfering with scroll events in other windows when the switcher is hidden.
// - SelectionState is a separate ObservableObject used ONLY for selection index changes.
//   This allows lightweight, reactive updates for hover/selection without recreating the entire view.
// - Heavy state changes (windows array, dimensions) still use SharedPreviewWindowCoordinator.refreshUI()
final class PreviewStateCoordinator {
    /// Lightweight ObservableObject for selection state - used by SwiftUI views for reactive updates
    let selectionState = SelectionState()

    /// Current selection index - proxied through selectionState for reactive updates
    var currIndex: Int {
        get { selectionState.currentIndex }
        set { selectionState.currentIndex = newValue }
    }

    var windowSwitcherActive: Bool = false

    var hasMovedSinceOpen: Bool = false
    var lastInputWasKeyboard: Bool {
        get { selectionState.lastInputWasKeyboard }
        set { selectionState.lastInputWasKeyboard = newValue }
    }

    var initialHoverLocation: CGPoint?
    var isKeyboardScrolling: Bool = false
    var fullWindowPreviewActive: Bool = false
    var windows: [WindowInfo] = []

    /// When true, this coordinator is used for settings preview and should NOT interact with SharedPreviewWindowCoordinator
    var isMockCoordinator: Bool = false
    var shouldScrollToIndex: Bool {
        get { selectionState.shouldScrollToIndex }
        set { selectionState.shouldScrollToIndex = newValue }
    }

    var searchQuery: String = "" {
        didSet {
            if windowSwitcherActive {
                Task { @MainActor in
                    updateIndexForSearch()
                }
            }
        }
    }

    var hasActiveSearch: Bool {
        !searchQuery.isEmpty
    }

    var overallMaxPreviewDimension: CGPoint = .zero
    var windowDimensionsMap: [Int: WindowImageSizingCalculations.WindowDimensions] = [:]
    private var lastKnownBestGuessMonitor: NSScreen?

    // Cached settings - read once when window is shown, not on every render
    var previewSettings: WindowPreviewSettingsCache?
    var containerSettings: HoverContainerSettingsCache?

    /// Refreshes the cached settings from UserDefaults. Call this once when showing the preview window.
    @MainActor
    func refreshSettingsCache() {
        previewSettings = WindowPreviewSettingsCache.current()
        containerSettings = HoverContainerSettingsCache.current()
    }

    enum WindowState {
        case windowSwitcher
        case fullWindowPreview
        case both
    }

    @MainActor
    func setShowing(_ state: WindowState? = .both, toState: Bool) {
        let oldSwitcherState = windowSwitcherActive
        switch state {
        case .windowSwitcher:
            windowSwitcherActive = toState
        case .fullWindowPreview:
            fullWindowPreviewActive = toState
        case .both:
            windowSwitcherActive = toState
            fullWindowPreviewActive = toState
        case .none:
            return
        }

        if !oldSwitcherState, windowSwitcherActive {
            hasMovedSinceOpen = false
            lastInputWasKeyboard = true
            initialHoverLocation = nil
            isKeyboardScrolling = false
        }

        // If window switcher state changed and we have windows, recalculate dimensions
        if oldSwitcherState != windowSwitcherActive, !windows.isEmpty {
            if let monitor = lastKnownBestGuessMonitor {
                let dockPosition = DockUtils.getDockPosition()
                recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor)
            }
        }
    }

    @MainActor
    func setIndex(to: Int, shouldScroll: Bool = true, fromKeyboard: Bool = true) {
        let oldIndex = currIndex
        if fromKeyboard {
            initialHoverLocation = nil
            hasMovedSinceOpen = false
        }

        // Capture last live preview frame as thumbnail for the previous window
        // This updates the thumbnail when user moves away from a window that had live preview
        if windowSwitcherActive,
           oldIndex >= 0, oldIndex < windows.count,
           oldIndex != to,
           Defaults[.windowSwitcherLivePreviewScope] == .selectedWindowOnly
        {
            let previousWindow = windows[oldIndex]
            if let lastFrame = LiveCaptureManager.shared.getLastFrame(for: previousWindow.id) {
                windows[oldIndex].image = lastFrame
                windows[oldIndex].imageCapturedTime = Date()
            }
        }

        let newIndex = (to >= 0 && to < windows.count) ? to : -1

        // Use SelectionState for reactive updates - this triggers SwiftUI view updates
        // without recreating the entire view hierarchy (fixes cursor disappearance)
        selectionState.setIndex(newIndex, shouldScroll: shouldScroll, fromKeyboard: fromKeyboard)
    }

    @MainActor
    func setWindows(_ newWindows: [WindowInfo], dockPosition: DockPosition, bestGuessMonitor: NSScreen, isMockPreviewActive: Bool = false) {
        windows = newWindows
        lastKnownBestGuessMonitor = bestGuessMonitor

        if currIndex >= windows.count {
            currIndex = windows.isEmpty ? -1 : windows.count - 1
        }

        recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: isMockPreviewActive)
    }

    @MainActor
    func updateWindow(at index: Int, with newInfo: WindowInfo) {
        guard index >= 0, index < windows.count else { return }
        windows[index] = newInfo

        // Trigger UI refresh when a window is updated (e.g., thumbnail refresh)
        if !isMockCoordinator {
            SharedPreviewWindowCoordinator.activeInstance?.refreshUI()
        }
    }

    @MainActor
    func removeWindow(at indexToRemove: Int) {
        guard indexToRemove >= 0, indexToRemove < windows.count else { return }

        let oldCurrIndex = currIndex
        windows.remove(at: indexToRemove)

        if windows.isEmpty {
            currIndex = -1
            if !isMockCoordinator {
                SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
            }
            return
        }

        if oldCurrIndex == indexToRemove {
            currIndex = min(indexToRemove, windows.count - 1)
        } else if oldCurrIndex > indexToRemove {
            currIndex = oldCurrIndex - 1
        }

        if currIndex >= windows.count {
            currIndex = windows.count - 1
        }

        // Recompute dimensions after removing window
        if let monitor = lastKnownBestGuessMonitor {
            let dockPosition = DockUtils.getDockPosition()
            recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor)
        }

        // Trigger UI refresh after removing window
        if !isMockCoordinator {
            SharedPreviewWindowCoordinator.activeInstance?.refreshUI()
        }
    }

    @MainActor
    func removeWindow(byAx ax: AXUIElement) {
        guard let indexToRemove = windows.firstIndex(where: { $0.axElement == ax }) else {
            return // Window not found
        }
        removeWindow(at: indexToRemove)
    }

    @MainActor
    func addWindows(_ newWindowsToAdd: [WindowInfo]) {
        guard !newWindowsToAdd.isEmpty else { return }

        // When the window switcher is active, this coordinator represents a global list
        // (windows across many apps). In that case, do NOT gate by PID.
        // PID gating is only meant for single-app hover previews.
        let gated: [WindowInfo]
        if windowSwitcherActive {
            gated = newWindowsToAdd
        } else {
            // Gate additions by PID of the currently displayed windows (if any)
            guard let currentPid = windows.first?.app.processIdentifier else {
                // No active windows context; ignore additions to avoid cross-app injection
                return
            }
            gated = newWindowsToAdd.filter { $0.app.processIdentifier == currentPid }
        }

        var windowsWereAdded = false
        for newWin in gated {
            if !windows.contains(where: { $0.id == newWin.id }) {
                windows.append(newWin)
                windowsWereAdded = true
            }
        }

        // Recompute dimensions if any windows were added
        if windowsWereAdded, let monitor = lastKnownBestGuessMonitor {
            let dockPosition = DockUtils.getDockPosition()
            recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor)

            // Trigger UI refresh after adding windows
            if !isMockCoordinator {
                SharedPreviewWindowCoordinator.activeInstance?.refreshUI()
            }
        }
    }

    @MainActor
    func removeAllWindows() {
        windows.removeAll()
        currIndex = -1 // Reset to no selection
        if !isMockCoordinator {
            SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
        }
    }

    @MainActor
    func recomputeAndPublishDimensions(dockPosition: DockPosition, bestGuessMonitor: NSScreen, isMockPreviewActive: Bool = false) {
        let panelSize = getWindowSize()

        let newOverallMaxDimension = WindowImageSizingCalculations.calculateOverallMaxDimensions(
            windows: windows,
            dockPosition: dockPosition,
            isWindowSwitcherActive: windowSwitcherActive,
            isMockPreviewActive: isMockPreviewActive,
            sharedPanelWindowSize: panelSize
        )

        let newDimensionsMap = WindowImageSizingCalculations.precomputeWindowDimensions(
            windows: windows,
            overallMaxDimensions: newOverallMaxDimension,
            bestGuessMonitor: bestGuessMonitor,
            dockPosition: dockPosition,
            isWindowSwitcherActive: windowSwitcherActive,
            previewMaxColumns: Defaults[.previewMaxColumns],
            previewMaxRows: Defaults[.previewMaxRows],
            switcherMaxRows: Defaults[.switcherMaxRows],
            switcherMaxColumns: Defaults[.switcherMaxColumns]
        )

        overallMaxPreviewDimension = newOverallMaxDimension
        windowDimensionsMap = newDimensionsMap
    }

    @MainActor
    private func updateIndexForSearch() {
        let oldIndex = currIndex
        if !hasActiveSearch {
            if currIndex >= windows.count {
                currIndex = windows.isEmpty ? -1 : 0
            }
        } else {
            let filtered = filteredWindowIndices()
            currIndex = filtered.first ?? -1
        }
        // Trigger UI refresh when index changes from search
        if currIndex != oldIndex, !isMockCoordinator {
            SharedPreviewWindowCoordinator.activeInstance?.refreshUI()
        }
    }

    /// Returns the indices of windows that match the current search query.
    /// If no search is active, returns all window indices.
    func filteredWindowIndices() -> [Int] {
        guard windowSwitcherActive, !searchQuery.isEmpty else {
            return Array(windows.indices)
        }

        let query = searchQuery.lowercased()
        let fuzziness = Defaults[.searchFuzziness]

        return windows.enumerated().compactMap { idx, win in
            let appName = win.app.localizedName?.lowercased() ?? ""
            let windowTitle = (win.windowName ?? "").lowercased()
            return (StringMatchingUtil.fuzzyMatch(query: query, target: appName, fuzziness: fuzziness) ||
                StringMatchingUtil.fuzzyMatch(query: query, target: windowTitle, fuzziness: fuzziness)) ? idx : nil
        }
    }
}
