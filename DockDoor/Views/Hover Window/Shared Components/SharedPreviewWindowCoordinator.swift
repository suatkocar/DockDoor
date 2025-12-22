import Defaults
import QuartzCore
import Sparkle
import SwiftUI

enum ArrowDirection {
    case left, right, up, down
}

enum EmbeddedContentType: Equatable {
    case media(bundleIdentifier: String)
    case calendar(bundleIdentifier: String)
    case none
}

final class SharedPreviewWindowCoordinator: NSPanel {
    weak static var activeInstance: SharedPreviewWindowCoordinator?

    let windowSwitcherCoordinator = PreviewStateCoordinator()
    private let dockManager = DockAutoHideManager()
    private var searchWindow: SearchWindow?

    private(set) var appName: String = ""
    var currentlyDisplayedPID: pid_t?
    var mouseIsWithinPreviewWindow: Bool = false
    private var onWindowTap: (() -> Void)?
    private var pendingShowWorkItem: DispatchWorkItem?
    private var fullPreviewWindow: NSPanel?

    var windowSize: CGSize = getWindowSize()

    private var previousHoverWindowOrigin: CGPoint?

    private(set) var hasScreenRecordingPermission: Bool = PermissionsChecker.hasScreenRecordingPermission()

    var pinnedWindows: [String: NSWindow] = [:]

    // Cached hosting view for instant display (eliminates ~50-70ms view recreation)
    // Using AnyView so we can set EmptyView() when hiding - this forces SwiftUI to dismantle
    // all views and remove their event monitors, fixing scroll blocking in Settings
    private var cachedHostingView: NSHostingView<AnyView>?

    // Cached size for instant positioning (eliminates ~20-30ms fittingSize overhead)
    private var cachedWindowSize: CGSize?
    private var cachedWindowCount: Int = 0
    private var cachedIsWindowSwitcher: Bool = false

    init() {
        let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless]
        super.init(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false)
        SharedPreviewWindowCoordinator.activeInstance = self
        setupWindow()
        setupSearchWindow()
    }

    deinit {
        if SharedPreviewWindowCoordinator.activeInstance === self {
            SharedPreviewWindowCoordinator.activeInstance = nil
        }
        dockManager.cleanup()
    }

    private func setupWindow() {
        level = Defaults[.raisedWindowLevel] ? .popUpMenu : .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        // Disable window animations for instant appearance
        animationBehavior = .none

        if let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) {
            colorSpace = NSColorSpace(cgColorSpace: p3ColorSpace)
        }
    }

    private func setupSearchWindow() {
        if Defaults[.enableWindowSwitcherSearch] {
            if searchWindow == nil {
                searchWindow = SearchWindow(previewCoordinator: windowSwitcherCoordinator)
            }
        } else {
            searchWindow?.hideSearch()
            searchWindow = nil
        }
    }

    func updateSearchWindow(with text: String) {
        guard Defaults[.enableWindowSwitcherSearch] else { return }
        if searchWindow == nil { setupSearchWindow() }
        if searchWindow?.isFocused != true {
            searchWindow?.updateSearchText(text)
        }
    }

    func focusSearchWindow() {
        guard Defaults[.enableWindowSwitcherSearch] else { return }
        if searchWindow == nil { setupSearchWindow() }
        guard let searchWindow else { return }
        searchWindow.showSearch(relativeTo: self)
        searchWindow.focusSearchField()
    }

    var isSearchWindowFocused: Bool {
        searchWindow?.isFocused ?? false
    }

    /// Manually refresh the UI when PreviewStateCoordinator state changes
    /// This is required because PreviewStateCoordinator is no longer an ObservableObject
    @MainActor
    func refreshUI() {
        guard isVisible, let cached = cachedHostingView else { return }

        let updateAvailable = (NSApp.delegate as? AppDelegate)?.updaterState.anUpdateIsAvailable ?? false
        let currentDockPosition = DockUtils.getDockPosition()

        let hoverView = WindowPreviewHoverContainer(
            appName: appName,
            onWindowTap: onWindowTap,
            dockPosition: currentDockPosition,
            mouseLocation: nil,
            bestGuessMonitor: NSScreen.main ?? NSScreen.screens.first!,
            dockItemElement: nil,
            windowSwitcherCoordinator: windowSwitcherCoordinator,
            mockPreviewActive: false,
            updateAvailable: updateAvailable,
            embeddedContentType: .none,
            hasScreenRecordingPermission: hasScreenRecordingPermission
        )

        cached.rootView = AnyView(hoverView)
    }

    private func isMediaApp(bundleIdentifier: String?) -> Bool {
        guard let bundleId = bundleIdentifier else { return false }
        return bundleId == spotifyAppIdentifier || bundleId == appleMusicAppIdentifier
    }

    private func isCalendarApp(bundleIdentifier: String?) -> Bool {
        guard let bundleId = bundleIdentifier else { return false }
        return bundleId == calendarAppIdentifier
    }

    private func getEmbeddedContentType(for bundleIdentifier: String?) -> EmbeddedContentType {
        guard let bundleId = bundleIdentifier else { return .none }

        if isMediaApp(bundleIdentifier: bundleId) {
            return .media(bundleIdentifier: bundleId)
        } else if isCalendarApp(bundleIdentifier: bundleId) {
            return .calendar(bundleIdentifier: bundleId)
        }

        return .none
    }

    func hideWindow() {
        // Cancel any pending show operations first - critical for quick release handling
        pendingShowWorkItem?.cancel()
        pendingShowWorkItem = nil

        guard isVisible else { return }

        DragPreviewCoordinator.shared.endDragging()
        hideFullPreviewWindow()

        // Hide search window
        searchWindow?.hideSearch()

        // CRITICAL: Explicitly stop live preview streams to ensure cleanup
        // SwiftUI's onDisappear may not fire reliably on quick modifier key releases
        Task { await LiveCaptureManager.shared.panelClosed() }

        if let currentContent = contentView {
            currentContent.removeFromSuperview()
        }
        contentView = nil

        // CRITICAL: Explicitly remove all TrackpadGestureModifier monitors
        // SwiftUI doesn't immediately dismantle views when rootView changes, so we force it
        TrackpadEventMonitor.Coordinator.removeAllMonitors()

        // Set rootView to EmptyView to help SwiftUI dismantle views
        if let cached = cachedHostingView {
            cached.rootView = AnyView(EmptyView())
        }

        cachedWindowSize = nil
        cachedWindowCount = 0
        cachedIsWindowSwitcher = false
        appName = ""
        currentlyDisplayedPID = nil
        mouseIsWithinPreviewWindow = false

        let currentDockPos = DockUtils.getDockPosition()
        let currentScreen = NSScreen.main ?? NSScreen.screens.first!
        windowSwitcherCoordinator.setWindows([], dockPosition: currentDockPos, bestGuessMonitor: currentScreen)
        windowSwitcherCoordinator.setShowing(.both, toState: false)
        dockManager.restoreDockState()

        // Resign key/main window status to fix scroll issues in other windows (Settings)
        if isKeyWindow {
            resignKey()
        }
        if isMainWindow {
            resignMain()
        }
        makeFirstResponder(nil)
        orderOut(nil)
    }

    @MainActor
    private func performShowView(_ view: some View,
                                 mouseLocation: CGPoint?,
                                 mouseScreen: NSScreen,
                                 dockItemElement: AXUIElement?,
                                 dockPositionOverride: DockPosition? = nil)
    {
        let hostingView = NSHostingView(rootView: view)

        if let oldContentView = contentView {
            oldContentView.removeFromSuperview()
        }
        contentView = hostingView

        let newHoverWindowSize = hostingView.fittingSize
        let position: CGPoint

        if let validDockItemElement = dockItemElement {
            position = calculateWindowPosition(mouseLocation: mouseLocation,
                                               windowSize: newHoverWindowSize,
                                               screen: mouseScreen,
                                               dockItemElement: validDockItemElement,
                                               dockPositionOverride: dockPositionOverride)

            // Prevent rendering if position calculation failed for cmd-tab
            if dockPositionOverride == .cmdTab, position == .zero {
                if let oldContentView = contentView {
                    oldContentView.removeFromSuperview()
                }
                contentView = nil
                return
            }
        } else {
            position = centerWindowOnScreen(size: newHoverWindowSize, screen: mouseScreen)
        }

        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        applyWindowFrame(finalFrame, animated: true)
        previousHoverWindowOrigin = position
    }

    @MainActor
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint? = nil, mouseScreen: NSScreen, dockItemElement: AXUIElement?,
                                                  animated: Bool, centerOnScreen: Bool = false,
                                                  centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil,
                                                  embeddedContentType: EmbeddedContentType = .none,
                                                  dockPositionOverride: DockPosition? = nil)
    {
        // Disable implicit animations for instant UI updates
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        windowSwitcherCoordinator.setShowing(centeredHoverWindowState, toState: centerOnScreen)

        let currentDockPosition = dockPositionOverride ?? DockUtils.getDockPosition()
        let windowCount = windowSwitcherCoordinator.windows.count
        let isWindowSwitcher = centerOnScreen

        // Create new SwiftUI view with current data
        let updateAvailable = (NSApp.delegate as? AppDelegate)?.updaterState.anUpdateIsAvailable ?? false
        let hoverView = WindowPreviewHoverContainer(
            appName: appName,
            onWindowTap: onWindowTap,
            dockPosition: currentDockPosition,
            mouseLocation: mouseLocation,
            bestGuessMonitor: mouseScreen,
            dockItemElement: dockItemElement,
            windowSwitcherCoordinator: windowSwitcherCoordinator,
            mockPreviewActive: false,
            updateAvailable: updateAvailable,
            embeddedContentType: embeddedContentType,
            hasScreenRecordingPermission: hasScreenRecordingPermission
        )

        // OPTIMIZATION: Reuse NSHostingView instance, just update rootView
        // This eliminates NSHostingView creation overhead (~30-50ms)
        let hostingView: NSHostingView<AnyView>
        if let cached = cachedHostingView {
            cached.rootView = AnyView(hoverView)
            hostingView = cached
        } else {
            hostingView = NSHostingView(rootView: AnyView(hoverView))
            cachedHostingView = hostingView
        }

        if contentView !== hostingView {
            if let oldContentView = contentView {
                oldContentView.removeFromSuperview()
            }
            contentView = hostingView
        }

        // OPTIMIZATION: Use cached size when window count is same to avoid expensive fittingSize
        // fittingSize triggers full SwiftUI layout calculation (~20-30ms)
        let newHoverWindowSize: CGSize

        if let cached = cachedWindowSize,
           cachedWindowCount == windowCount,
           cachedIsWindowSwitcher == isWindowSwitcher,
           windowCount > 0
        {
            // Use cached size for instant positioning
            newHoverWindowSize = cached
        } else {
            // Calculate new size and cache it
            newHoverWindowSize = hostingView.fittingSize
            cachedWindowSize = newHoverWindowSize
            cachedWindowCount = windowCount
            cachedIsWindowSwitcher = isWindowSwitcher
        }

        let position: CGPoint
        if centerOnScreen {
            position = centerWindowOnScreen(size: newHoverWindowSize, screen: mouseScreen)
        } else {
            if let validDockItemElement = dockItemElement {
                position = calculateWindowPosition(mouseLocation: mouseLocation, windowSize: newHoverWindowSize, screen: mouseScreen, dockItemElement: validDockItemElement, dockPositionOverride: dockPositionOverride)

                // Prevent rendering if position calculation failed for cmd-tab
                if dockPositionOverride == .cmdTab, position == .zero {
                    if let oldContentView = contentView {
                        oldContentView.removeFromSuperview()
                    }
                    contentView = nil
                    return
                }
            } else {
                position = centerWindowOnScreen(size: newHoverWindowSize, screen: mouseScreen)
            }
        }
        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        applyWindowFrame(finalFrame, animated: animated)
        previousHoverWindowOrigin = position

        // Now that the main panel has a valid frame, position the search window (if active)
        if windowSwitcherCoordinator.windowSwitcherActive, Defaults[.enableWindowSwitcherSearch] {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if searchWindow == nil { setupSearchWindow() }
                searchWindow?.showSearch(relativeTo: self)
            }
        }
    }

    @MainActor
    private func showFullPreviewWindow(for windowInfo: WindowInfo, on screen: NSScreen) {
        if fullPreviewWindow == nil {
            let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless]
            fullPreviewWindow = NSPanel(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false)
            fullPreviewWindow?.level = .floating
            fullPreviewWindow?.isOpaque = false
            fullPreviewWindow?.backgroundColor = .clear
            fullPreviewWindow?.hasShadow = true
            fullPreviewWindow?.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
            fullPreviewWindow?.hidesOnDeactivate = false
            fullPreviewWindow?.becomesKeyOnlyIfNeeded = true

            if let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) {
                fullPreviewWindow?.colorSpace = NSColorSpace(cgColorSpace: p3ColorSpace)
            }
        }

        let windowSize = (try? windowInfo.axElement.size()) ?? CGSize(width: screen.frame.width, height: screen.frame.height)
        let axPosition = (try? windowInfo.axElement.position()) ?? CGPoint(x: screen.frame.midX, y: screen.frame.midY)

        let convertedPosition = DockObserver.cgPointFromNSPoint(axPosition, forScreen: screen)
        let adjustedPosition = CGPoint(x: convertedPosition.x, y: convertedPosition.y - windowSize.height)

        let flippedIconRect = CGRect(origin: adjustedPosition, size: windowSize)

        let previewView = FullSizePreviewView(windowInfo: windowInfo, windowSize: windowSize)
        let hostingView = NSHostingView(rootView: previewView)

        if let oldFullPreviewContent = fullPreviewWindow?.contentView {
            oldFullPreviewContent.removeFromSuperview()
        }
        fullPreviewWindow?.contentView = hostingView

        fullPreviewWindow?.setFrame(flippedIconRect, display: true)
        fullPreviewWindow?.makeKeyAndOrderFront(nil)
    }

    @MainActor
    func hideFullPreviewWindow() {
        fullPreviewWindow?.orderOut(nil)
        if let currentFullPreviewContent = fullPreviewWindow?.contentView {
            currentFullPreviewContent.removeFromSuperview()
        }
        fullPreviewWindow?.contentView = nil
        fullPreviewWindow = nil
    }

    private func centerWindowOnScreen(size: CGSize, screen: NSScreen) -> CGPoint {
        CGPoint(
            x: screen.frame.midX - (size.width / 2),
            y: screen.frame.midY - (size.height / 2)
        )
    }

    private func calculateWindowPosition(mouseLocation: CGPoint?, windowSize: CGSize, screen: NSScreen, dockItemElement: AXUIElement, dockPositionOverride: DockPosition? = nil) -> CGPoint {
        guard let mouseLocation else { return .zero }
        let screenFrame = screen.frame
        let dockPosition = dockPositionOverride ?? DockUtils.getDockPosition()

        do {
            guard let currentPosition = try dockItemElement.position(),
                  let currentSize = try dockItemElement.size()
            else {
                return .zero
            }
            let currentIconRect = CGRect(origin: currentPosition, size: currentSize)
            let flippedIconRect = CGRect(
                origin: DockObserver.cgPointFromNSPoint(currentIconRect.origin, forScreen: screen),
                size: currentIconRect.size
            )

            var xPosition: CGFloat
            var yPosition: CGFloat

            switch dockPosition {
            case .bottom, .cmdTab:
                xPosition = flippedIconRect.midX - (windowSize.width / 2)
                yPosition = flippedIconRect.minY
            case .left:
                xPosition = flippedIconRect.maxX
                yPosition = flippedIconRect.midY - (windowSize.height / 2) - flippedIconRect.height
            case .right:
                xPosition = screenFrame.maxX - flippedIconRect.width - windowSize.width
                yPosition = flippedIconRect.minY - (windowSize.height / 2)
            default:
                xPosition = mouseLocation.x - (windowSize.width / 2)
                yPosition = mouseLocation.y - (windowSize.height / 2)
            }

            let bufferFromDock = Defaults[.bufferFromDock]
            switch dockPosition {
            case .left:
                xPosition += bufferFromDock
            case .right:
                xPosition -= bufferFromDock
            case .bottom:
                yPosition += bufferFromDock
            case .cmdTab:
                yPosition += 5
            default:
                break
            }

            xPosition = max(screenFrame.minX, min(xPosition, screenFrame.maxX - windowSize.width))
            yPosition = max(screenFrame.minY, min(yPosition, screenFrame.maxY - windowSize.height))

            return CGPoint(x: xPosition, y: yPosition)

        } catch {
            return .zero
        }
    }

    @MainActor
    private func applyWindowFrame(_ frame: CGRect, animated: Bool) {
        let shouldAnimate = animated && Defaults[.showAnimations]

        if shouldAnimate {
            // Window is appearing for the first time, apply slide animation
            let dockPosition = DockUtils.getDockPosition()
            let animationOffset: CGFloat = 7.0
            var startFrame = frame

            switch dockPosition {
            case .bottom:
                startFrame.origin.y -= animationOffset
            case .left:
                startFrame.origin.x -= animationOffset
            case .right:
                startFrame.origin.x += animationOffset
            default:
                startFrame.origin.y -= animationOffset
            }

            setFrame(startFrame, display: true)
            orderFront(nil)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.175
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(frame, display: true)
            }
        } else {
            setFrame(frame, display: true)
        }

        alphaValue = 1.0
        makeKeyAndOrderFront(nil)
    }

    @MainActor
    private func performDisplay(
        appName: String,
        windows: [WindowInfo],
        mouseLocation: CGPoint?,
        mouseScreen: NSScreen?,
        dockItemElement: AXUIElement?,
        centeredHoverWindowState: PreviewStateCoordinator.WindowState?,
        onWindowTap: (() -> Void)?,
        bundleIdentifier: String?,
        dockPositionOverride: DockPosition? = nil,
        initialIndex: Int? = nil
    ) {
        // Refresh settings cache once at display time, not on every render
        windowSwitcherCoordinator.refreshSettingsCache()

        let screen = mouseScreen ?? NSScreen.main!
        var finalEmbeddedContentType: EmbeddedContentType = .none
        var useBigStandaloneViewInstead = false
        var viewForBigStandalone: AnyView?

        if let bundleId = bundleIdentifier {
            let actualAppContentType = getEmbeddedContentType(for: bundleId)

            switch actualAppContentType {
            case let .media(mediaBundleId):
                if Defaults[.showSpecialAppControls] {
                    let hasValidWindows = windows.contains { !$0.isMinimized && !$0.isHidden }
                    let shouldUseBigControlsForNoValidWindows = Defaults[.showBigControlsWhenNoValidWindows] &&
                        (windows.isEmpty || !hasValidWindows)

                    if Defaults[.useEmbeddedMediaControls], !shouldUseBigControlsForNoValidWindows {
                        finalEmbeddedContentType = .media(bundleIdentifier: mediaBundleId)
                    } else {
                        useBigStandaloneViewInstead = true
                        viewForBigStandalone = AnyView(MediaControlsView(
                            appName: appName,
                            bundleIdentifier: mediaBundleId,
                            dockPosition: dockPositionOverride ?? DockUtils.getDockPosition(),
                            bestGuessMonitor: screen,
                            dockItemElement: dockItemElement,
                            isEmbeddedMode: false
                        ))
                    }
                }
            case let .calendar(calendarBundleId):
                if Defaults[.showSpecialAppControls] {
                    let hasValidWindows = windows.contains { !$0.isMinimized && !$0.isHidden }
                    let shouldUseBigControlsForNoValidWindows = Defaults[.showBigControlsWhenNoValidWindows] &&
                        (windows.isEmpty || !hasValidWindows)

                    if Defaults[.useEmbeddedMediaControls], !shouldUseBigControlsForNoValidWindows {
                        finalEmbeddedContentType = .calendar(bundleIdentifier: calendarBundleId)
                    } else {
                        useBigStandaloneViewInstead = true
                        viewForBigStandalone = AnyView(CalendarView(
                            appName: appName,
                            bundleIdentifier: calendarBundleId,
                            dockPosition: dockPositionOverride ?? DockUtils.getDockPosition(),
                            bestGuessMonitor: screen,
                            dockItemElement: dockItemElement,
                            isEmbeddedMode: false
                        ))
                    }
                }
            case .none:
                break
            }
        }

        if let dockItemElement {
            currentlyDisplayedPID = try? dockItemElement.pid()
        }

        if useBigStandaloneViewInstead, let viewToShow = viewForBigStandalone {
            performShowView(viewToShow, mouseLocation: mouseLocation, mouseScreen: screen, dockItemElement: dockItemElement, dockPositionOverride: dockPositionOverride)
        } else {
            performShowWindow(
                appName: appName,
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: screen,
                dockItemElement: dockItemElement,
                centeredHoverWindowState: centeredHoverWindowState,
                onWindowTap: onWindowTap,
                embeddedContentType: finalEmbeddedContentType,
                dockPositionOverride: dockPositionOverride,
                initialIndex: initialIndex
            )
        }

        dockManager.preventDockHiding(centeredHoverWindowState != nil)
    }

    @MainActor
    private func performShowWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint?,
                                   mouseScreen: NSScreen?, dockItemElement: AXUIElement?,
                                   centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil,
                                   onWindowTap: (() -> Void)?,
                                   embeddedContentType: EmbeddedContentType = .none,
                                   dockPositionOverride: DockPosition? = nil, initialIndex: Int? = nil)
    {
        guard !windows.isEmpty else { return }

        let shouldCenterOnScreen = centeredHoverWindowState != .none

        let screen = mouseScreen ?? NSScreen.main!

        // Only hide full preview if we're about to show a NEW full preview
        // Don't hide it when just refreshing the main dock preview
        if centeredHoverWindowState == .fullWindowPreview {
            hideFullPreviewWindow()
        }

        if centeredHoverWindowState == .fullWindowPreview,
           let windowInfo = windows.first,
           let windowPosition = try? windowInfo.axElement.position(),
           let windowScreen = windowPosition.screen()
        {
            showFullPreviewWindow(for: windowInfo, on: windowScreen)
        } else {
            self.appName = appName
            let currentDockPosition = DockUtils.getDockPosition()

            windowSwitcherCoordinator.setWindows(windows, dockPosition: currentDockPosition, bestGuessMonitor: screen)

            // Set initial index for window switcher
            if let initialIndex {
                windowSwitcherCoordinator.setIndex(to: initialIndex, shouldScroll: false)
            }

            self.onWindowTap = onWindowTap

            updateContentViewSizeAndPosition(mouseLocation: mouseLocation, mouseScreen: screen, dockItemElement: dockItemElement, animated: !shouldCenterOnScreen,
                                             centerOnScreen: shouldCenterOnScreen, centeredHoverWindowState: centeredHoverWindowState,
                                             embeddedContentType: embeddedContentType, dockPositionOverride: dockPositionOverride)
        }
    }

    @MainActor
    func cycleWindows(goBackwards: Bool) {
        let coordinator = windowSwitcherCoordinator
        guard !coordinator.windows.isEmpty else { return }

        if coordinator.windowSwitcherActive, coordinator.hasActiveSearch {
            return
        }

        let windowsCount = coordinator.windows.count
        var newIndex = coordinator.currIndex

        if !coordinator.windowSwitcherActive, coordinator.currIndex < 0 {
            newIndex = goBackwards ? (windowsCount - 1) : 0
            if windowsCount == 0 { newIndex = -1 }
        } else if windowsCount > 0 {
            let dockPosition = DockUtils.getDockPosition()
            let isHorizontalFlow = dockPosition.isHorizontalFlow || coordinator.windowSwitcherActive

            let direction: ArrowDirection = if isHorizontalFlow {
                goBackwards ? .left : .right
            } else {
                goBackwards ? .up : .down
            }

            newIndex = WindowPreviewHoverContainer.navigateWindowSwitcher(
                from: coordinator.currIndex,
                direction: direction,
                totalItems: windowsCount,
                dockPosition: dockPosition,
                isWindowSwitcherActive: coordinator.windowSwitcherActive
            )
        } else {
            newIndex = -1
        }
        coordinator.setIndex(to: newIndex)
    }

    @MainActor
    func selectAndBringToFrontCurrentWindow() {
        let coordinator = windowSwitcherCoordinator
        let currentIndex = coordinator.currIndex

        guard currentIndex >= 0, currentIndex < coordinator.windows.count else {
            hideWindow()
            return
        }

        let selectedWindow = coordinator.windows[currentIndex]
        selectedWindow.bringToFront()
        hideWindow()
    }

    @MainActor
    func navigateWithArrowKey(direction: ArrowDirection) {
        let coordinator = windowSwitcherCoordinator
        guard !coordinator.windows.isEmpty else { return }

        coordinator.hasMovedSinceOpen = false
        coordinator.initialHoverLocation = nil

        let threshold = Defaults[.windowSwitcherCompactThreshold]
        let isListViewMode = coordinator.windowSwitcherActive && threshold > 0 && coordinator.windows.count >= threshold

        // Handle list view navigation (up/down only, with filtering support)
        if isListViewMode {
            let filteredIndices = coordinator.filteredWindowIndices()
            let indicesToUse = coordinator.hasActiveSearch ? filteredIndices : Array(coordinator.windows.indices)
            guard !indicesToUse.isEmpty else { return }

            let currentPos = indicesToUse.firstIndex(of: coordinator.currIndex) ?? 0
            let newPos: Int = switch direction {
            case .up, .left:
                currentPos > 0 ? currentPos - 1 : indicesToUse.count - 1
            case .down, .right:
                (currentPos + 1) % indicesToUse.count
            }
            coordinator.setIndex(to: indicesToUse[newPos])
            return
        }

        // Handle filtered navigation when search is active (grid view)
        if coordinator.windowSwitcherActive, coordinator.hasActiveSearch {
            let filteredIndices = coordinator.filteredWindowIndices()
            guard !filteredIndices.isEmpty else { return }

            guard let currentFilteredPos = filteredIndices.firstIndex(of: coordinator.currIndex) else {
                coordinator.setIndex(to: filteredIndices.first ?? 0)
                return
            }

            let newFilteredPos = WindowPreviewHoverContainer.navigateWindowSwitcher(
                from: currentFilteredPos,
                direction: direction,
                totalItems: filteredIndices.count,
                dockPosition: .bottom,
                isWindowSwitcherActive: true
            )

            coordinator.setIndex(to: filteredIndices[newFilteredPos])
            return
        }

        let windowsCount = coordinator.windows.count
        var newIndex = coordinator.currIndex

        if !coordinator.windowSwitcherActive, coordinator.currIndex < 0 {
            newIndex = windowsCount > 0 ? 0 : -1
        } else {
            let dockPosition = DockUtils.getDockPosition()

            newIndex = WindowPreviewHoverContainer.navigateWindowSwitcher(
                from: coordinator.currIndex,
                direction: direction,
                totalItems: windowsCount,
                dockPosition: dockPosition,
                isWindowSwitcherActive: coordinator.windowSwitcherActive
            )
        }
        coordinator.setIndex(to: newIndex)
    }

    @MainActor
    func performActionOnCurrentWindow(action: WindowAction) {
        let coordinator = windowSwitcherCoordinator
        guard coordinator.currIndex >= 0, coordinator.currIndex < coordinator.windows.count else {
            return
        }

        let window = coordinator.windows[coordinator.currIndex]
        let originalIndex = coordinator.currIndex

        let result = action.perform(on: window, keepPreviewOnQuit: false)

        switch result {
        case .dismissed:
            hideWindow()
        case let .windowUpdated(updatedWindow):
            coordinator.updateWindow(at: originalIndex, with: updatedWindow)
        case .windowRemoved:
            coordinator.removeWindow(at: originalIndex)
        case .appWindowsRemoved, .noChange:
            break
        }
    }

    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint? = nil, mouseScreen: NSScreen? = nil,
                    dockItemElement: AXUIElement?,
                    overrideDelay: Bool = false, centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil,
                    onWindowTap: (() -> Void)? = nil, bundleIdentifier: String? = nil,
                    bypassDockMouseValidation: Bool = false,
                    dockPositionOverride: DockPosition? = nil, initialIndex: Int? = nil)
    {
        let shouldSkipDelay = overrideDelay || (Defaults[.useDelayOnlyForInitialOpen] && isVisible)
        let delay = shouldSkipDelay ? 0 : Defaults[.hoverWindowOpenDelay]

        // Cancel any previous pending show
        pendingShowWorkItem?.cancel()
        pendingShowWorkItem = nil

        // INSTANT PATH: When delay is 0 and we're on MainActor, call performDisplay directly
        // This eliminates async overhead for maximum speed
        if delay == 0, Thread.isMainThread {
            // For dock previews, validate mouse is still over expected dock item (prevents flickering)
            if !bypassDockMouseValidation, let expectedBundleId = bundleIdentifier {
                if let currentDockItemStatus = DockObserver.activeInstance?.getDockItemAppStatusUnderMouse() {
                    let currentBundleId: String? = switch currentDockItemStatus.status {
                    case let .success(app): app.bundleIdentifier
                    case let .notRunning(bundleId): bundleId
                    case .notFound: nil
                    }
                    let matches = currentBundleId == expectedBundleId
                    guard matches else { return }
                }
            }

            performDisplay(
                appName: appName,
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: mouseScreen,
                dockItemElement: dockItemElement,
                centeredHoverWindowState: centeredHoverWindowState,
                onWindowTap: onWindowTap,
                bundleIdentifier: bundleIdentifier,
                dockPositionOverride: dockPositionOverride,
                initialIndex: initialIndex
            )
            return
        }

        // DELAYED PATH: Use DispatchWorkItem for dock hover previews with delay
        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem { [weak self] in
            guard let self, !workItem.isCancelled else { return }

            // Check if mouse entered the preview window and we're trying to show a different app
            if mouseIsWithinPreviewWindow,
               let currentPID = currentlyDisplayedPID,
               let expectedBundleId = bundleIdentifier,
               let expectedApp = NSRunningApplication.runningApplications(withBundleIdentifier: expectedBundleId).first,
               currentPID != expectedApp.processIdentifier
            { return }

            // Final validation: ensure mouse is still over the expected dock item
            if !bypassDockMouseValidation {
                if let expectedBundleId = bundleIdentifier {
                    guard let currentDockItemStatus = DockObserver.activeInstance?.getDockItemAppStatusUnderMouse() else { return }
                    let currentBundleId: String? = switch currentDockItemStatus.status {
                    case let .success(app): app.bundleIdentifier
                    case let .notRunning(bundleId): bundleId
                    case .notFound: nil
                    }
                    let matches = currentBundleId == expectedBundleId
                    guard matches else { return }
                }
            }

            // For delayed path, we're already on main thread from asyncAfter, call directly
            guard !workItem.isCancelled else { return }
            performDisplay(
                appName: appName,
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: mouseScreen,
                dockItemElement: dockItemElement,
                centeredHoverWindowState: centeredHoverWindowState,
                onWindowTap: onWindowTap,
                bundleIdentifier: bundleIdentifier,
                dockPositionOverride: dockPositionOverride,
                initialIndex: initialIndex
            )
        }

        pendingShowWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
