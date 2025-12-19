import AppKit
import Carbon
import Carbon.HIToolbox.Events
import Defaults

private class KeybindHelperUserInfo {
    let instance: KeybindHelper
    init(instance: KeybindHelper) {
        self.instance = instance
    }
}

struct UserKeyBind: Codable, Defaults.Serializable {
    var keyCode: UInt16
    var modifierFlags: Int
}

private class WindowSwitchingCoordinator {
    private var isProcessingSwitcher = false
    let stateManager = WindowSwitcherStateManager()
    private var uiRenderingTask: Task<Void, Never>?
    private var currentSessionId = UUID()

    /// Set BEFORE UI opens, cleared when dismissed - critical for catching quick modifier releases
    var isSwitcherBeingUsed = false

    private static var lastUpdateAllWindowsTime: Date?
    private static let updateAllWindowsThrottleInterval: TimeInterval = 60.0

    /// Synchronous version for instant mode - no async overhead, no blocking guard
    @MainActor
    func handleWindowSwitchingSync(
        previewCoordinator: SharedPreviewWindowCoordinator,
        isModifierPressed: Bool,
        isShiftPressed: Bool,
        mode: SwitcherInvocationMode = .allWindows
    ) {
        if stateManager.isActive, !previewCoordinator.isVisible {
            stateManager.reset()
        }

        if stateManager.isActive {
            let uiIndex = previewCoordinator.windowSwitcherCoordinator.currIndex
            if uiIndex >= 0, uiIndex != stateManager.currentIndex {
                stateManager.setIndex(uiIndex)
            }

            if isShiftPressed {
                stateManager.cycleBackward()
            } else {
                stateManager.cycleForward()
            }

            previewCoordinator.windowSwitcherCoordinator.hasMovedSinceOpen = false
            previewCoordinator.windowSwitcherCoordinator.initialHoverLocation = nil
            previewCoordinator.windowSwitcherCoordinator.setIndex(to: stateManager.currentIndex)
        } else if isModifierPressed {
            initializeWindowSwitchingSync(
                previewCoordinator: previewCoordinator,
                mode: mode
            )
        }
    }

    @MainActor
    func handleWindowSwitching(
        previewCoordinator: SharedPreviewWindowCoordinator,
        isModifierPressed: Bool,
        isShiftPressed: Bool,
        mode: SwitcherInvocationMode = .allWindows
    ) async {
        guard !isProcessingSwitcher else { return }
        isProcessingSwitcher = true
        defer { isProcessingSwitcher = false }

        if stateManager.isActive, !previewCoordinator.isVisible {
            stateManager.reset()
        }

        if stateManager.isActive {
            // TODO: Consolidate WindowSwitcherStateManager and PreviewStateCoordinator into a single index system
            let uiIndex = previewCoordinator.windowSwitcherCoordinator.currIndex
            if uiIndex >= 0, uiIndex != stateManager.currentIndex {
                stateManager.setIndex(uiIndex)
            }

            if isShiftPressed {
                stateManager.cycleBackward()
            } else {
                stateManager.cycleForward()
            }

            previewCoordinator.windowSwitcherCoordinator.hasMovedSinceOpen = false
            previewCoordinator.windowSwitcherCoordinator.initialHoverLocation = nil

            previewCoordinator.windowSwitcherCoordinator.setIndex(to: stateManager.currentIndex)
        } else if isModifierPressed {
            await initializeWindowSwitching(
                previewCoordinator: previewCoordinator,
                mode: mode
            )
        }
    }

    // Cache for space refresh to avoid calling every activation
    private static var lastSpaceRefreshTime: Date?
    private static let spaceRefreshThrottleInterval: TimeInterval = 0.5 // Refresh at most every 500ms

    /// Fully synchronous initialization for instant mode - maximum speed
    @MainActor
    private func initializeWindowSwitchingSync(
        previewCoordinator: SharedPreviewWindowCoordinator,
        mode: SwitcherInvocationMode = .allWindows
    ) {
        // OPTIMIZATION: Throttle space refresh - it's expensive and rarely changes
        let now = Date()
        if let lastRefresh = WindowSwitchingCoordinator.lastSpaceRefreshTime,
           now.timeIntervalSince(lastRefresh) < WindowSwitchingCoordinator.spaceRefreshThrottleInterval
        {
            // Skip space refresh - use cached data
        } else {
            refreshSpacesInfo()
            WindowUtil.updateSpaceInfoForAllWindows()
            WindowSwitchingCoordinator.lastSpaceRefreshTime = now
        }

        // Get windows immediately from cache (fast with windowless apps cache)
        var windows = WindowUtil.getAllWindowsOfAllApps()

        // Apply space filter using sync version
        let filterBySpace = (mode == .currentSpaceOnly || mode == .activeAppCurrentSpace)
            || (mode == .allWindows && Defaults[.showWindowsFromCurrentSpaceOnlyInSwitcher])
        if filterBySpace {
            windows = WindowUtil.filterWindowsByCurrentSpaceSync(windows)
        }

        // Apply active app filter
        let filterByApp = (mode == .activeAppOnly || mode == .activeAppCurrentSpace)
            || (mode == .allWindows && Defaults[.limitSwitcherToFrontmostApp])
        if filterByApp {
            windows = WindowUtil.getWindowsForFrontmostApp(from: windows)
        }

        // Apply hidden windows filter
        if !Defaults[.includeHiddenWindowsInSwitcher] {
            windows = windows.filter { !$0.isHidden && !$0.isMinimized }
        }

        // Sort windows
        windows = WindowUtil.sortWindowsForSwitcher(windows)

        guard !windows.isEmpty else { return }

        currentSessionId = UUID()
        let sessionId = currentSessionId

        stateManager.initializeWithWindows(windows)

        let currentMouseLocation = DockObserver.getMousePosition()
        let targetScreen = getTargetScreenForSwitcher()

        uiRenderingTask?.cancel()

        // Show UI synchronously
        renderWindowSwitcherUISync(
            previewCoordinator: previewCoordinator,
            windows: windows,
            currentMouseLocation: currentMouseLocation,
            targetScreen: targetScreen,
            sessionId: sessionId
        )

        // Uncomment for performance debugging (also uncomment timing variables above):
        // let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        // print("TIMING[Switcher]: Total=\(String(format: "%.1f", totalTime))ms, windows=\(windows.count) | space=\(String(format: "%.1f", spaceRefreshTime))ms, get=\(String(format: "%.1f", getWindowsTime))ms, filter=\(String(format: "%.1f", filterSortTime))ms, render=\(String(format: "%.1f", renderTime))ms")

        // Background tasks - don't block UI
        Task.detached(priority: .low) {
            await WindowUtil.discoverAllWindowsFromAllSpaces()
        }
    }

    @MainActor
    private func initializeWindowSwitching(
        previewCoordinator: SharedPreviewWindowCoordinator,
        mode: SwitcherInvocationMode = .allWindows
    ) async {
        // Quick sync updates
        refreshSpacesInfo()
        WindowUtil.updateSpaceInfoForAllWindows()

        // Get windows immediately from cache (fast)
        var windows = WindowUtil.getAllWindowsOfAllApps()

        // Discover windows from all spaces in background (don't block switcher opening)
        Task.detached(priority: .userInitiated) {
            await WindowUtil.discoverAllWindowsFromAllSpaces()
        }

        // Apply space filter based on mode or default setting
        let filterBySpace = (mode == .currentSpaceOnly || mode == .activeAppCurrentSpace)
            || (mode == .allWindows && Defaults[.showWindowsFromCurrentSpaceOnlyInSwitcher])
        if filterBySpace {
            windows = await WindowUtil.filterWindowsByCurrentSpace(windows)
        }

        // Apply active app filter based on mode or default setting
        let filterByApp = (mode == .activeAppOnly || mode == .activeAppCurrentSpace)
            || (mode == .allWindows && Defaults[.limitSwitcherToFrontmostApp])
        if filterByApp {
            windows = WindowUtil.getWindowsForFrontmostApp(from: windows)
        }

        // Apply hidden windows filter (always respect the global setting)
        if !Defaults[.includeHiddenWindowsInSwitcher] {
            windows = windows.filter { !$0.isHidden && !$0.isMinimized }
        }

        // Sort windows
        windows = WindowUtil.sortWindowsForSwitcher(windows)

        guard !windows.isEmpty else { return }

        currentSessionId = UUID()
        let sessionId = currentSessionId

        stateManager.initializeWithWindows(windows)

        let currentMouseLocation = DockObserver.getMousePosition()
        let targetScreen = getTargetScreenForSwitcher()

        uiRenderingTask?.cancel()

        // Normal mode: use delayed Task
        uiRenderingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            await renderWindowSwitcherUI(
                previewCoordinator: previewCoordinator,
                windows: windows,
                currentMouseLocation: currentMouseLocation,
                targetScreen: targetScreen,
                initialIndex: stateManager.currentIndex,
                sessionId: sessionId
            )
        }

        Task.detached(priority: .low) {
            let now = Date()
            let shouldUpdate: Bool = if let lastUpdate = WindowSwitchingCoordinator.lastUpdateAllWindowsTime {
                now.timeIntervalSince(lastUpdate) >= WindowSwitchingCoordinator.updateAllWindowsThrottleInterval
            } else {
                true
            }

            guard shouldUpdate else { return }
            WindowSwitchingCoordinator.lastUpdateAllWindowsTime = now
            await WindowUtil.updateAllWindowsInCurrentSpace()
        }
    }

    /// Synchronous version for instant mode - no async overhead
    @MainActor
    private func renderWindowSwitcherUISync(
        previewCoordinator: SharedPreviewWindowCoordinator,
        windows: [WindowInfo],
        currentMouseLocation: CGPoint,
        targetScreen: NSScreen,
        sessionId: UUID
    ) {
        guard sessionId == currentSessionId else { return }
        guard stateManager.isActive else { return }
        guard isSwitcherBeingUsed else { return }

        if previewCoordinator.isVisible, previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
            previewCoordinator.windowSwitcherCoordinator.setIndex(to: stateManager.currentIndex)
            return
        }

        let showWindowLambda = { (mouseLocation: NSPoint?, mouseScreen: NSScreen?) in
            guard self.isSwitcherBeingUsed else { return }
            previewCoordinator.showWindow(
                appName: "Window Switcher",
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: mouseScreen,
                dockItemElement: nil,
                overrideDelay: true,
                centeredHoverWindowState: .windowSwitcher,
                onWindowTap: {
                    self.cancelSwitching()
                    Task { @MainActor in
                        previewCoordinator.hideWindow()
                    }
                },
                initialIndex: self.stateManager.currentIndex
            )
        }

        switch Defaults[.windowSwitcherPlacementStrategy] {
        case .pinnedToScreen:
            let screenCenter = NSPoint(x: targetScreen.frame.midX, y: targetScreen.frame.midY)
            showWindowLambda(screenCenter, targetScreen)
        case .screenWithLastActiveWindow:
            showWindowLambda(nil, nil)
        case .screenWithMouse:
            let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
            let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)
            showWindowLambda(convertedMouseLocation, mouseScreen)
        }
    }

    @MainActor
    private func renderWindowSwitcherUI(
        previewCoordinator: SharedPreviewWindowCoordinator,
        windows: [WindowInfo],
        currentMouseLocation: CGPoint,
        targetScreen: NSScreen,
        initialIndex: Int,
        sessionId: UUID
    ) async {
        guard sessionId == currentSessionId else { return }
        guard stateManager.isActive else { return }
        // Check if switcher was cancelled during async wait (prevents race condition)
        guard isSwitcherBeingUsed else { return }

        if previewCoordinator.isVisible, previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
            previewCoordinator.windowSwitcherCoordinator.setIndex(to: stateManager.currentIndex)
            return
        }
        let showWindowLambda = { (mouseLocation: NSPoint?, mouseScreen: NSScreen?) in
            // Double-check before showing - release could have happened
            guard self.isSwitcherBeingUsed else { return }
            previewCoordinator.showWindow(
                appName: "Window Switcher",
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: mouseScreen,
                dockItemElement: nil,
                overrideDelay: true,
                centeredHoverWindowState: .windowSwitcher,
                onWindowTap: {
                    self.cancelSwitching()
                    Task { @MainActor in
                        previewCoordinator.hideWindow()
                    }
                },
                initialIndex: self.stateManager.currentIndex
            )
        }

        switch Defaults[.windowSwitcherPlacementStrategy] {
        case .pinnedToScreen:
            let screenCenter = NSPoint(x: targetScreen.frame.midX, y: targetScreen.frame.midY)
            showWindowLambda(screenCenter, targetScreen)
        case .screenWithLastActiveWindow:
            showWindowLambda(nil, nil)
        case .screenWithMouse:
            let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
            let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)
            showWindowLambda(convertedMouseLocation, mouseScreen)
        }
    }

    private func getTargetScreenForSwitcher() -> NSScreen {
        if Defaults[.windowSwitcherPlacementStrategy] == .pinnedToScreen,
           let pinnedScreen = NSScreen.findScreen(byIdentifier: Defaults[.pinnedScreenIdentifier])
        {
            return pinnedScreen
        }
        let mouseLocation = DockObserver.getMousePosition()
        return NSScreen.screenContainingMouse(mouseLocation)
    }

    func selectCurrentWindow() -> WindowInfo? {
        guard stateManager.isActive else { return nil }

        let selectedWindow = stateManager.getCurrentWindow()
        currentSessionId = UUID()
        stateManager.reset()
        uiRenderingTask?.cancel()
        return selectedWindow
    }

    func isStateManagerActive() -> Bool {
        stateManager.isActive
    }

    /// Synchronous cycling for Tab key - no async overhead
    @MainActor
    func cycleSelection(
        previewCoordinator: SharedPreviewWindowCoordinator,
        backward: Bool
    ) {
        guard stateManager.isActive else { return }

        // Sync index if needed
        let uiIndex = previewCoordinator.windowSwitcherCoordinator.currIndex
        if uiIndex >= 0, uiIndex != stateManager.currentIndex {
            stateManager.setIndex(uiIndex)
        }

        if backward {
            stateManager.cycleBackward()
        } else {
            stateManager.cycleForward()
        }

        previewCoordinator.windowSwitcherCoordinator.setIndex(to: stateManager.currentIndex)
    }

    func cancelSwitching() {
        isSwitcherBeingUsed = false
        currentSessionId = UUID()
        stateManager.reset()
        uiRenderingTask?.cancel()
    }
}

class KeybindHelper {
    private let previewCoordinator: SharedPreviewWindowCoordinator
    private let windowSwitchingCoordinator = WindowSwitchingCoordinator()

    private var isSwitcherModifierKeyPressed: Bool = false
    private var isShiftKeyPressedGeneral: Bool = false
    private var hasProcessedModifierRelease: Bool = false
    private var preventSwitcherHideOnRelease: Bool = false

    // Track the invocation mode for alternate keybinds
    private var currentInvocationMode: SwitcherInvocationMode = .allWindows

    // Track Command key state to detect key-up fallback for lingering previews
    private var isCommandKeyCurrentlyDown: Bool = false
    private var lastCmdTabObservedActive: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var monitorTimer: Timer?
    private var unmanagedEventTapUserInfo: Unmanaged<KeybindHelperUserInfo>?
    private var shiftCycleTimer: Timer?
    private var tabCycleTimer: Timer?
    private var isTabKeyDown: Bool = false

    // Carbon hotkey manager for instant response
    private let carbonHotkeyManager = CarbonHotkeyManager.shared
    private var useCarbonHotkeys: Bool { Defaults[.instantWindowSwitcher] }
    private var hotkeyObservation: Defaults.Observation?

    init(previewCoordinator: SharedPreviewWindowCoordinator) {
        self.previewCoordinator = previewCoordinator
        setupCarbonHotkeys()
        setupEventTap()
        startMonitoring()
        setupHotkeyObservation()
    }

    private func setupHotkeyObservation() {
        // Re-register Carbon hotkeys when settings change
        hotkeyObservation = Defaults.observe(
            keys: .UserKeybind, .alternateKeybindKey, .instantWindowSwitcher
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.carbonHotkeyManager.updateHotkeys()
            }
        }
    }

    func reset() {
        cleanup()
        resetState()
        setupCarbonHotkeys()
        setupEventTap()
        startMonitoring()
    }

    private func cleanup() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        shiftCycleTimer?.invalidate()
        shiftCycleTimer = nil
        tabCycleTimer?.invalidate()
        tabCycleTimer = nil
        isTabKeyDown = false
        carbonHotkeyManager.cleanup()
        removeEventTap()
    }

    private func resetState() {
        isSwitcherModifierKeyPressed = false
        isShiftKeyPressedGeneral = false
        preventSwitcherHideOnRelease = false
        currentInvocationMode = .allWindows
    }

    // MARK: - Carbon Hotkey Setup

    private func setupCarbonHotkeys() {
        guard Defaults[.enableWindowSwitcher] else { return }
        guard useCarbonHotkeys else { return }

        // Setup Carbon hotkeys with callback - fires on main thread instantly
        carbonHotkeyManager.setup { [weak self] hotkeyId, isPressed in
            guard let self else { return }
            if isPressed {
                handleCarbonHotkeyPressed(hotkeyId)
            }
            // Release is handled by flagsChanged for modifier keys
        }
    }

    /// Handle Carbon hotkey press - runs on main thread instantly
    private func handleCarbonHotkeyPressed(_ hotkeyId: Int) {
        guard Defaults[.enableWindowSwitcher] else { return }
        guard useCarbonHotkeys else { return }

        // Set flags synchronously - we're already on main thread!
        windowSwitchingCoordinator.isSwitcherBeingUsed = true
        hasProcessedModifierRelease = false

        // Determine mode based on hotkey ID
        let mode: SwitcherInvocationMode = if hotkeyId == CarbonHotkeyManager.HotkeyID.primary.rawValue {
            .allWindows
        } else if hotkeyId == CarbonHotkeyManager.HotkeyID.alternate.rawValue {
            Defaults[.alternateKeybindMode]
        } else {
            .allWindows
        }

        currentInvocationMode = mode

        // Update modifier state from current flags
        let currentFlags = NSEvent.modifierFlags
        let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
        updateModifierStateFromNSEventFlags(currentFlags, keyBoardShortcutSaved: keyBoardShortcutSaved)

        // Call handleKeybindActivation directly - Carbon callbacks run on main thread
        // Use MainActor.assumeIsolated since we know we're on main thread
        MainActor.assumeIsolated {
            self.handleKeybindActivation(mode: mode)
        }
    }

    /// Update modifier state from NSEvent flags (used by Carbon callbacks)
    private func updateModifierStateFromNSEventFlags(_ flags: NSEvent.ModifierFlags, keyBoardShortcutSaved: UserKeyBind) {
        let wantsAlt = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskAlternate.rawValue)) != 0
        let wantsCtrl = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskControl.rawValue)) != 0
        let wantsCmd = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskCommand.rawValue)) != 0

        let altPressed = flags.contains(.option)
        let ctrlPressed = flags.contains(.control)
        let cmdPressed = flags.contains(.command)

        isSwitcherModifierKeyPressed = (wantsAlt && altPressed) || (wantsCtrl && ctrlPressed) || (wantsCmd && cmdPressed)
        isShiftKeyPressedGeneral = flags.contains(.shift)
    }

    private func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkEventTapStatus()
        }
    }

    private func checkEventTapStatus() {
        guard let eventTap, CGEvent.tapIsEnabled(tap: eventTap) else {
            reset()
            return
        }
    }

    private static let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        return Unmanaged<KeybindHelperUserInfo>.fromOpaque(refcon).takeUnretainedValue().instance.handleEvent(proxy: proxy, type: type, event: event)
    }

    private func setupEventTap() {
        // Always listen for keyDown/keyUp because we need:
        // 1. Tab key repeat for cycling when switcher is visible
        // 2. Arrow keys, Escape, Enter for navigation
        // 3. Search input when switcher is active
        // Carbon hotkeys handle the INITIAL activation, but CGEventTap handles
        // subsequent keys when the switcher is already open
        let eventMask: Int = (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue)

        let userInfo = KeybindHelperUserInfo(instance: self)
        unmanagedEventTapUserInfo = Unmanaged.passRetained(userInfo)

        guard let newEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: KeybindHelper.eventCallback,
            userInfo: unmanagedEventTapUserInfo?.toOpaque()
        ) else {
            unmanagedEventTapUserInfo?.release()
            unmanagedEventTapUserInfo = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                print("Retrying KeybindHelper event tap setup...")
                self?.setupEventTap()
            }
            return
        }

        eventTap = newEventTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newEventTap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: newEventTap, enable: true)
        }
    }

    private func removeEventTap() {
        if let eventTap, let runLoopSource {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            unmanagedEventTapUserInfo?.release()
            unmanagedEventTapUserInfo = nil
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
            let (currentSwitcherModifierIsPressed, currentShiftState) = updateModifierStatesFromFlags(event: event, keyBoardShortcutSaved: keyBoardShortcutSaved)

            // Track Command up/down explicitly for Cmd+Tab fallback behavior
            let cmdNowDown = event.flags.contains(.maskCommand)
            if isCommandKeyCurrentlyDown, !cmdNowDown {
                DockObserver.activeInstance?.stopCmdTabPolling()

                if Defaults[.enableCmdTabEnhancements], lastCmdTabObservedActive,
                   previewCoordinator.isVisible,
                   !previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive
                {
                    Task { @MainActor in
                        if self.previewCoordinator.windowSwitcherCoordinator.currIndex >= 0 {
                            self.previewCoordinator.selectAndBringToFrontCurrentWindow()
                        } else {
                            self.previewCoordinator.hideWindow()
                        }
                    }
                }
                lastCmdTabObservedActive = false
            }
            isCommandKeyCurrentlyDown = cmdNowDown

            // Use DispatchQueue.main.async instead of Task for faster execution
            // This is critical for catching quick modifier releases
            DispatchQueue.main.async { [weak self] in
                self?.handleModifierEvent(currentSwitcherModifierIsPressed: currentSwitcherModifierIsPressed, currentShiftState: currentShiftState)
            }

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Detect Cmd+Tab press to start on-demand polling for the switcher
            if Defaults[.enableCmdTabEnhancements],
               keyCode == Int64(kVK_Tab),
               flags.contains(.maskCommand)
            {
                let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
                let isCustomKeybind = (keyCode == keyBoardShortcutSaved.keyCode) &&
                    (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskCommand.rawValue)) != 0

                if !isCustomKeybind {
                    DockObserver.activeInstance?.startCmdTabPolling()
                }
            }

            // If system Cmd+Tab switcher is active, optionally handle arrows when enhancements are enabled
            if DockObserver.isCmdTabSwitcherActive {
                lastCmdTabObservedActive = true
                if Defaults[.enableCmdTabEnhancements],
                   previewCoordinator.isVisible
                {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let hasSelection = previewCoordinator.windowSwitcherCoordinator.currIndex >= 0
                    let flags = event.flags
                    switch keyCode {
                    case Int64(kVK_Escape):
                        Task { @MainActor in
                            self.previewCoordinator.hideWindow()
                        }
                        return nil
                    case Int64(kVK_LeftArrow):
                        if hasSelection {
                            Task { @MainActor in
                                self.previewCoordinator.navigateWithArrowKey(direction: .left)
                            }
                            // Consume only when a selection is active (focused mode)
                            return nil
                        } else {
                            // Let system Cmd+Tab handle left/right until user focuses with Up
                            return Unmanaged.passUnretained(event)
                        }
                    case Int64(kVK_RightArrow):
                        if hasSelection {
                            Task { @MainActor in
                                self.previewCoordinator.navigateWithArrowKey(direction: .right)
                            }
                            return nil
                        } else {
                            return Unmanaged.passUnretained(event)
                        }
                    case Int64(kVK_UpArrow):
                        return Unmanaged.passUnretained(event)
                    case Int64(kVK_DownArrow):
                        // If a preview is selected, first Down just deselects and is consumed.
                        // Subsequent Down (with no selection) is passed through to system Exposé.
                        if hasSelection {
                            Task { @MainActor in
                                self.previewCoordinator.windowSwitcherCoordinator.setIndex(to: -1)
                            }
                            return nil
                        } else {
                            return Unmanaged.passUnretained(event)
                        }
                    default:
                        // Allow activation via Cmd+A (when not yet focused) and
                        // Command-based actions when a preview is focused
                        if flags.contains(.maskCommand) {
                            if keyCode == Int64(kVK_ANSI_A) {
                                Task { @MainActor in
                                    let currentIndex = self.previewCoordinator.windowSwitcherCoordinator.currIndex
                                    let windowCount = self.previewCoordinator.windowSwitcherCoordinator.windows.count
                                    let isShift = flags.contains(.maskShift)

                                    if !hasSelection {
                                        // First activation: select first preview
                                        self.previewCoordinator.windowSwitcherCoordinator.setIndex(to: 0)
                                        Defaults[.hasSeenCmdTabFocusHint] = true
                                    } else if isShift {
                                        // Cmd+Shift+A: cycle backward
                                        let newIndex = currentIndex > 0 ? currentIndex - 1 : windowCount - 1
                                        self.previewCoordinator.windowSwitcherCoordinator.setIndex(to: newIndex)
                                    } else {
                                        // Cmd+A: cycle forward
                                        let newIndex = (currentIndex + 1) % windowCount
                                        self.previewCoordinator.windowSwitcherCoordinator.setIndex(to: newIndex)
                                    }
                                }
                                return nil
                            }
                        }

                        if hasSelection, flags.contains(.maskCommand) {
                            // Check configurable Cmd+key shortcuts
                            if let action = getActionForCmdShortcut(keyCode: keyCode) {
                                Task { @MainActor in
                                    self.previewCoordinator.performActionOnCurrentWindow(action: action)
                                }
                                return nil
                            }
                        }
                    }
                }
                // Not enhancing or not in our cmdTab context — let the system handle it.
                return Unmanaged.passUnretained(event)
            }

            if keyCode == Int64(kVK_Tab), previewCoordinator.isVisible {
                if previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
                    let hasActiveSearch = previewCoordinator.windowSwitcherCoordinator.hasActiveSearch
                    if !hasActiveSearch, !isTabKeyDown {
                        isTabKeyDown = true
                        let isShiftHeld = flags.contains(.maskShift)
                        DispatchQueue.main.async { [weak self] in
                            self?.handleTabKeyDown(isShiftHeld: isShiftHeld)
                        }
                    }
                    return nil
                } else {
                    let direction: ArrowDirection = flags.contains(.maskShift) ? .left : .right
                    DispatchQueue.main.async { [weak self] in
                        self?.previewCoordinator.navigateWithArrowKey(direction: direction)
                    }
                    return nil
                }
            }

            let (shouldConsume, actionTask, shouldSetSwitcherFlag, syncAction) = determineActionForKeyDown(event: event)
            // Set isSwitcherBeingUsed SYNCHRONOUSLY before any async work - must be set before release can happen
            if shouldSetSwitcherFlag {
                windowSwitchingCoordinator.isSwitcherBeingUsed = true
            }
            // For instant mode, execute on MainActor to eliminate async overhead
            if let syncAction {
                Task { @MainActor in
                    syncAction()
                }
            } else if let task = actionTask {
                Task { @MainActor in
                    await task()
                }
            }
            if shouldConsume { return nil }

        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == kVK_Tab {
                isTabKeyDown = false
                DispatchQueue.main.async { [weak self] in
                    self?.tabCycleTimer?.invalidate()
                    self?.tabCycleTimer = nil
                }
            }

        case .leftMouseDown:
            if previewCoordinator.isVisible,
               previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive
            {
                let clickLocation = NSEvent.mouseLocation
                let windowFrame = previewCoordinator.frame

                if windowFrame.contains(clickLocation) {
                    let flags = event.flags
                    if flags.contains(.maskControl) {
                        var newFlags = flags
                        newFlags.remove(.maskControl)
                        event.flags = newFlags
                    }
                } else {
                    Task { @MainActor in
                        self.windowSwitchingCoordinator.cancelSwitching()
                        self.previewCoordinator.hideWindow()
                        self.preventSwitcherHideOnRelease = false
                        self.hasProcessedModifierRelease = true
                    }
                }
            }

        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func updateModifierStatesFromFlags(event: CGEvent, keyBoardShortcutSaved: UserKeyBind) -> (currentSwitcherModifierIsPressed: Bool, currentShiftState: Bool) {
        // Interpret saved mask by checking presence of standard CGEventFlag bits
        let saved = keyBoardShortcutSaved.modifierFlags
        let wantsAlt = (saved & Int(CGEventFlags.maskAlternate.rawValue)) != 0
        let wantsCtrl = (saved & Int(CGEventFlags.maskControl.rawValue)) != 0
        let wantsCmd = (saved & Int(CGEventFlags.maskCommand.rawValue)) != 0

        let flags = event.flags
        let hasAlt = flags.contains(.maskAlternate)
        let hasCtrl = flags.contains(.maskControl)
        let hasCmd = flags.contains(.maskCommand)

        let currentSwitcherModifierIsPressed = (wantsAlt && hasAlt) || (wantsCtrl && hasCtrl) || (wantsCmd && hasCmd)
        let currentShiftState = flags.contains(.maskShift)

        return (currentSwitcherModifierIsPressed, currentShiftState)
    }

    @MainActor
    private func handleModifierEvent(currentSwitcherModifierIsPressed: Bool, currentShiftState: Bool) {
        // If system Cmd+Tab switcher is active, do not engage DockDoor's own switcher logic
        if DockObserver.isCmdTabSwitcherActive { return }
        let oldSwitcherModifierState = isSwitcherModifierKeyPressed

        isSwitcherModifierKeyPressed = currentSwitcherModifierIsPressed
        isShiftKeyPressedGeneral = currentShiftState

        if preventSwitcherHideOnRelease, !previewCoordinator.isVisible {
            preventSwitcherHideOnRelease = false
        }

        if !oldSwitcherModifierState, currentSwitcherModifierIsPressed {
            hasProcessedModifierRelease = false
        }

        // Safety check: Catches cases where modifier release events arrive out of order or are dropped
        if windowSwitchingCoordinator.isSwitcherBeingUsed,
           !currentSwitcherModifierIsPressed,
           !Defaults[.preventSwitcherHide],
           !preventSwitcherHideOnRelease,
           !hasProcessedModifierRelease
        {
            // Verify modifier is truly released by checking current state
            let currentModifiers = NSEvent.modifierFlags
            let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
            let wantsAlt = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskAlternate.rawValue)) != 0
            let wantsCtrl = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskControl.rawValue)) != 0
            let wantsCmd = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskCommand.rawValue)) != 0

            let modifierStillPressed = (wantsAlt && currentModifiers.contains(.option)) ||
                (wantsCtrl && currentModifiers.contains(.control)) ||
                (wantsCmd && currentModifiers.contains(.command))

            if !modifierStillPressed {
                hasProcessedModifierRelease = true
                preventSwitcherHideOnRelease = false
                stopShiftCycleTimer()
                stopTabCycleTimer()
                windowSwitchingCoordinator.isSwitcherBeingUsed = false
                if previewCoordinator.isVisible {
                    previewCoordinator.selectAndBringToFrontCurrentWindow()
                }
                windowSwitchingCoordinator.cancelSwitching()
                previewCoordinator.hideWindow()
                return
            }
        }

        let shouldCycleBackward = previewCoordinator.isVisible &&
            ((previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive && (currentSwitcherModifierIsPressed || Defaults[.preventSwitcherHide])) ||
                (!previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive))

        if currentShiftState, shouldCycleBackward {
            if shiftCycleTimer == nil {
                if windowSwitchingCoordinator.stateManager.isActive {
                    // Direct synchronous cycling
                    windowSwitchingCoordinator.cycleSelection(
                        previewCoordinator: previewCoordinator,
                        backward: true
                    )
                }
                shiftCycleTimer = Timer.scheduledTimer(withTimeInterval: TimerConstants.initialDelay, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    shiftCycleTimer = Timer.scheduledTimer(withTimeInterval: TimerConstants.repeatInterval, repeats: true) { [weak self] _ in
                        guard let self else { return }
                        guard previewCoordinator.windowSwitcherCoordinator.lastInputWasKeyboard else {
                            stopShiftCycleTimer()
                            return
                        }
                        if windowSwitchingCoordinator.stateManager.isActive {
                            DispatchQueue.main.async {
                                self.windowSwitchingCoordinator.cycleSelection(
                                    previewCoordinator: self.previewCoordinator,
                                    backward: true
                                )
                            }
                        }
                    }
                }
            }
        } else {
            shiftCycleTimer?.invalidate()
            shiftCycleTimer = nil
        }

        if !Defaults[.preventSwitcherHide], !preventSwitcherHideOnRelease, !(previewCoordinator.isSearchWindowFocused) {
            if oldSwitcherModifierState, !isSwitcherModifierKeyPressed, !hasProcessedModifierRelease {
                hasProcessedModifierRelease = true
                preventSwitcherHideOnRelease = false
                stopShiftCycleTimer()
                stopTabCycleTimer()

                // Handle release synchronously - isSwitcherBeingUsed flag is set BEFORE UI opens
                if windowSwitchingCoordinator.isSwitcherBeingUsed {
                    windowSwitchingCoordinator.isSwitcherBeingUsed = false

                    if previewCoordinator.isVisible, previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
                        previewCoordinator.selectAndBringToFrontCurrentWindow()
                        windowSwitchingCoordinator.cancelSwitching()
                    } else if windowSwitchingCoordinator.stateManager.isActive {
                        // Switcher was initializing but not yet visible - cancel and select
                        if let selectedWindow = windowSwitchingCoordinator.selectCurrentWindow() {
                            selectedWindow.bringToFront()
                        }
                        previewCoordinator.hideWindow()
                    } else {
                        // UI never opened - just cancel
                        windowSwitchingCoordinator.cancelSwitching()
                        previewCoordinator.hideWindow()
                    }
                }
            }
        }
    }

    private enum TimerConstants {
        static let initialDelay: TimeInterval = 0.4
        static let repeatInterval: TimeInterval = 0.05
    }

    private func stopShiftCycleTimer() {
        shiftCycleTimer?.invalidate()
        shiftCycleTimer = nil
    }

    private func stopTabCycleTimer() {
        tabCycleTimer?.invalidate()
        tabCycleTimer = nil
        isTabKeyDown = false
    }

    @MainActor
    private func handleTabKeyDown(isShiftHeld: Bool) {
        guard windowSwitchingCoordinator.stateManager.isActive else { return }

        // Direct synchronous cycling - no async overhead
        windowSwitchingCoordinator.cycleSelection(
            previewCoordinator: previewCoordinator,
            backward: isShiftHeld
        )

        tabCycleTimer?.invalidate()
        tabCycleTimer = Timer.scheduledTimer(withTimeInterval: TimerConstants.initialDelay, repeats: false) { [weak self] _ in
            guard let self, isTabKeyDown else { return }
            tabCycleTimer = Timer.scheduledTimer(withTimeInterval: TimerConstants.repeatInterval, repeats: true) { [weak self] _ in
                guard let self, isTabKeyDown else { return }
                guard previewCoordinator.windowSwitcherCoordinator.lastInputWasKeyboard else {
                    stopTabCycleTimer()
                    return
                }
                let currentShiftState = NSEvent.modifierFlags.contains(.shift)
                DispatchQueue.main.async {
                    self.windowSwitchingCoordinator.cycleSelection(
                        previewCoordinator: self.previewCoordinator,
                        backward: currentShiftState
                    )
                }
            }
        }
    }

    private func determineActionForKeyDown(event: CGEvent) -> (shouldConsume: Bool, actionTask: (() async -> Void)?, shouldSetSwitcherFlag: Bool, syncAction: (@MainActor () -> Void)?) {
        // Check if we should ignore keybinds for fullscreen blacklisted apps
        if WindowUtil.shouldIgnoreKeybindForFrontmostApp() {
            return (false, nil, false, nil)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
        let previewIsCurrentlyVisible = previewCoordinator.isVisible

        if previewIsCurrentlyVisible {
            if keyCode == kVK_Escape {
                return (true, {
                    self.stopShiftCycleTimer()
                    self.stopTabCycleTimer()
                    self.windowSwitchingCoordinator.cancelSwitching()
                    await self.previewCoordinator.hideWindow()
                    self.preventSwitcherHideOnRelease = false
                    self.hasProcessedModifierRelease = true
                }, false, nil)
            }

            if flags.contains(.maskCommand), previewCoordinator.windowSwitcherCoordinator.currIndex >= 0 {
                // Check configurable Cmd+key shortcuts
                if let action = getActionForCmdShortcut(keyCode: keyCode) {
                    return (true, { await self.previewCoordinator.performActionOnCurrentWindow(action: action) }, false, nil)
                }
            }
        }

        // Compute desired modifier press based on current event flags to avoid relying solely on flagsChanged ordering
        let wantsAlt = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskAlternate.rawValue)) != 0
        let wantsCtrl = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskControl.rawValue)) != 0
        let wantsCmd = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskCommand.rawValue)) != 0
        let isDesiredModifierPressedNow = (wantsAlt && flags.contains(.maskAlternate)) ||
            (wantsCtrl && flags.contains(.maskControl)) ||
            (wantsCmd && flags.contains(.maskCommand))

        let isExactSwitcherShortcutPressed = (isDesiredModifierPressedNow && keyCode == keyBoardShortcutSaved.keyCode) ||
            (!isDesiredModifierPressedNow && keyBoardShortcutSaved.modifierFlags == 0 && keyCode == keyBoardShortcutSaved.keyCode)

        if isExactSwitcherShortcutPressed {
            guard Defaults[.enableWindowSwitcher] else { return (false, nil, false, nil) }
            // When Carbon hotkeys are enabled, PASS THROUGH the event so Carbon can see it
            // shouldConsume = false means we don't eat the event
            if useCarbonHotkeys {
                // Let Carbon handle this - DON'T consume the event!
                return (false, nil, false, nil)
            }
            // Fallback for non-instant mode: use async handling
            return (true, { await self.handleKeybindActivation(mode: .allWindows) }, true, nil)
        }

        // Check alternate keybind (shares same modifier as primary keybind)
        if isDesiredModifierPressedNow {
            let alternateKey = Defaults[.alternateKeybindKey]
            if alternateKey != 0, keyCode == alternateKey {
                guard Defaults[.enableWindowSwitcher] else { return (false, nil, false, nil) }
                let mode = Defaults[.alternateKeybindMode]
                // When Carbon hotkeys are enabled, PASS THROUGH the event so Carbon can see it
                if useCarbonHotkeys {
                    // Let Carbon handle this - DON'T consume the event!
                    return (false, nil, false, nil)
                }
                // Fallback for non-instant mode: use async handling
                return (true, { await self.handleKeybindActivation(mode: mode) }, true, nil)
            }
        }

        if previewIsCurrentlyVisible {
            switch keyCode {
            case Int64(kVK_LeftArrow), Int64(kVK_RightArrow), Int64(kVK_UpArrow), Int64(kVK_DownArrow):
                let dir: ArrowDirection = switch keyCode {
                case Int64(kVK_LeftArrow):
                    .left
                case Int64(kVK_RightArrow):
                    .right
                case Int64(kVK_UpArrow):
                    .up
                default:
                    .down
                }
                return (true, { @MainActor in
                    self.previewCoordinator.navigateWithArrowKey(direction: dir)
                }, false, nil)
            case Int64(kVK_Return), Int64(kVK_ANSI_KeypadEnter):
                if previewCoordinator.windowSwitcherCoordinator.currIndex >= 0 {
                    return (true, makeEnterSelectionTask(), false, nil)
                }
            default:
                break
            }
        }

        if previewIsCurrentlyVisible,
           previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive,
           Defaults[.enableWindowSwitcherSearch],
           keyCode == Int64(kVK_ANSI_Slash) // Forward slash key
        {
            return (true, { @MainActor in
                self.previewCoordinator.focusSearchWindow()
                self.preventSwitcherHideOnRelease = true
            }, false, nil)
        }
        if previewIsCurrentlyVisible,
           previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive,
           Defaults[.enableWindowSwitcherSearch],
           !(previewCoordinator.isSearchWindowFocused)
        {
            if keyCode == Int64(kVK_Delete) {
                return (true, { @MainActor in
                    var query = self.previewCoordinator.windowSwitcherCoordinator.searchQuery
                    if !query.isEmpty {
                        query.removeLast()
                        self.previewCoordinator.windowSwitcherCoordinator.searchQuery = query
                        let windows = self.previewCoordinator.windowSwitcherCoordinator.windows
                        self.windowSwitchingCoordinator.stateManager.setSearchQuery(query, windows: windows)
                        SharedPreviewWindowCoordinator.activeInstance?.updateSearchWindow(with: query)

                        if query.isEmpty {
                            self.preventSwitcherHideOnRelease = false
                        }
                    }
                }, false, nil)
            }

            if !flags.contains(.maskCommand),
               let nsEvent = NSEvent(cgEvent: event),
               let characters = nsEvent.characters,
               !characters.isEmpty
            {
                let filteredChars = characters.filter { char in
                    char.isLetter || char.isNumber || char.isWhitespace ||
                        ".,!?-_()[]{}@#$%^&*+=|\\:;\"'<>/~`".contains(char)
                }
                if !filteredChars.isEmpty {
                    return (true, { @MainActor in
                        self.previewCoordinator.windowSwitcherCoordinator.searchQuery.append(contentsOf: filteredChars)
                        let newQuery = self.previewCoordinator.windowSwitcherCoordinator.searchQuery
                        let windows = self.previewCoordinator.windowSwitcherCoordinator.windows
                        self.windowSwitchingCoordinator.stateManager.setSearchQuery(newQuery, windows: windows)
                        SharedPreviewWindowCoordinator.activeInstance?.updateSearchWindow(with: newQuery)

                        if !newQuery.isEmpty {
                            self.preventSwitcherHideOnRelease = true
                        }
                    }, false, nil)
                }
            }
        }

        if previewIsCurrentlyVisible,
           previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive,
           keyCode == keyBoardShortcutSaved.keyCode,
           !isSwitcherModifierKeyPressed,
           keyBoardShortcutSaved.modifierFlags != 0,
           !flags.hasSuperfluousModifiers(ignoring: [.maskShift, .maskAlphaShift, .maskNumericPad])
        {
            // When Carbon hotkeys are enabled, they handle this directly
            if useCarbonHotkeys {
                return (true, nil, false, nil)
            }
            // Fallback for non-instant mode
            return (true, { await self.handleKeybindActivation() }, true, nil)
        }

        return (false, nil, false, nil)
    }

    private func makeEnterSelectionTask() -> (() async -> Void) {
        { @MainActor in
            self.preventSwitcherHideOnRelease = false

            if self.previewCoordinator.isVisible, self.previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
                self.previewCoordinator.selectAndBringToFrontCurrentWindow()
                self.windowSwitchingCoordinator.cancelSwitching()
                return
            }

            if let selectedWindow = self.windowSwitchingCoordinator.selectCurrentWindow() {
                selectedWindow.bringToFront()
                self.previewCoordinator.hideWindow()
            } else {
                self.previewCoordinator.selectAndBringToFrontCurrentWindow()
            }
        }
    }

    @MainActor
    private func handleKeybindActivation(mode: SwitcherInvocationMode = .allWindows) {
        guard Defaults[.enableWindowSwitcher] else { return }
        hasProcessedModifierRelease = false
        currentInvocationMode = mode

        if Defaults[.instantWindowSwitcher] {
            // Instant mode: call synchronously for maximum speed
            windowSwitchingCoordinator.handleWindowSwitchingSync(
                previewCoordinator: previewCoordinator,
                isModifierPressed: isSwitcherModifierKeyPressed,
                isShiftPressed: isShiftKeyPressedGeneral,
                mode: mode
            )
        } else {
            // Normal mode: use async for delayed display
            Task { @MainActor in
                await windowSwitchingCoordinator.handleWindowSwitching(
                    previewCoordinator: previewCoordinator,
                    isModifierPressed: self.isSwitcherModifierKeyPressed,
                    isShiftPressed: self.isShiftKeyPressedGeneral,
                    mode: mode
                )
            }
        }
    }

    /// Returns the action for a Cmd+key shortcut if the keyCode matches any configured shortcut
    private func getActionForCmdShortcut(keyCode: Int64) -> WindowAction? {
        let shortcut1Key = Defaults[.cmdShortcut1Key]
        let shortcut2Key = Defaults[.cmdShortcut2Key]
        let shortcut3Key = Defaults[.cmdShortcut3Key]

        switch keyCode {
        case Int64(shortcut1Key):
            let action = Defaults[.cmdShortcut1Action]
            return action != .none ? action : nil
        case Int64(shortcut2Key):
            let action = Defaults[.cmdShortcut2Action]
            return action != .none ? action : nil
        case Int64(shortcut3Key):
            let action = Defaults[.cmdShortcut3Action]
            return action != .none ? action : nil
        default:
            return nil
        }
    }
}

extension CGEventFlags {
    func hasSuperfluousModifiers(ignoring: CGEventFlags = []) -> Bool {
        let significantModifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        let relevantToCheck = significantModifiers.subtracting(ignoring)
        return !intersection(relevantToCheck).isEmpty
    }
}
