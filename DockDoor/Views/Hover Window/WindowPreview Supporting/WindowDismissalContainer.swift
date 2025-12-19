import Defaults
import SwiftUI

struct WindowDismissalContainer: NSViewRepresentable {
    let appName: String
    let bestGuessMonitor: NSScreen
    let dockPosition: DockPosition
    let dockItemElement: AXUIElement?
    let minimizeAllWindowsCallback: (_ wasAppActiveBeforeClick: Bool) -> Void

    func makeNSView(context: Context) -> MouseTrackingNSView {
        let view = MouseTrackingNSView(currentAppName: appName,
                                       bestGuessMonitor: bestGuessMonitor,
                                       dockPosition: dockPosition,
                                       dockItemElement: dockItemElement,
                                       minimizeAllWindowsCallback: minimizeAllWindowsCallback)
        view.resetOpacity()
        return view
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        // Restart timer if app name changed (view is being reused for different app)
        nsView.restartMonitoringIfNeeded(for: appName, dockItemElement: dockItemElement)
    }
}

class MouseTrackingNSView: NSView {
    private var currentAppName: String
    private let bestGuessMonitor: NSScreen
    private let dockPosition: DockPosition
    private var currentDockItemElement: AXUIElement?
    private let minimizeAllWindowsCallback: (_ wasAppActiveBeforeClick: Bool) -> Void
    private var fadeOutTimer: Timer?
    private let fadeOutDuration: TimeInterval
    private var inactivityCheckTimer: Timer?
    private let inactivityCheckInterval: TimeInterval
    private var inactivityCheckCount: Int = 0 // Track how many checks have occurred
    private var differentIconCount: Int = 0 // Track consecutive checks over different dock icon

    /// Restart monitoring if the app name has changed OR if timer was cleared (preview was hidden and re-shown)
    func restartMonitoringIfNeeded(for newAppName: String, dockItemElement: AXUIElement?) {
        // Restart if app changed OR if timer is nil (was cleared when preview was hidden)
        let needsRestart = newAppName != currentAppName || inactivityCheckTimer == nil

        if needsRestart {
            currentAppName = newAppName
            currentDockItemElement = dockItemElement
            clearTimers()
            startInactivityMonitoring()
        }
    }

    init(currentAppName: String, bestGuessMonitor: NSScreen, dockPosition: DockPosition, dockItemElement: AXUIElement?, minimizeAllWindowsCallback: @escaping (_ wasAppActiveBeforeClick: Bool) -> Void, frame frameRect: NSRect = .zero) {
        self.currentAppName = currentAppName
        self.bestGuessMonitor = bestGuessMonitor
        self.dockPosition = dockPosition
        currentDockItemElement = dockItemElement
        self.minimizeAllWindowsCallback = minimizeAllWindowsCallback
        fadeOutDuration = Defaults[.fadeOutDuration]
        inactivityCheckInterval = TimeInterval(Defaults[.inactivityTimeout])
        super.init(frame: frameRect)
        setupTrackingArea()
        startInactivityMonitoring()
        resetOpacityVisually()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    deinit {
        clearTimers()
    }

    private func clearTimers() {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        inactivityCheckTimer?.invalidate()
        inactivityCheckTimer = nil
    }

    private func startInactivityMonitoring() {
        inactivityCheckTimer?.invalidate()
        inactivityCheckCount = 0 // Reset counter
        differentIconCount = 0 // Reset different icon counter

        // Use minimum interval of 0.1s to prevent immediate firing before window is set up
        // When user sets 0, they want instant hide when mouse leaves - not before window shows
        let effectiveInterval = max(inactivityCheckInterval, 0.1)

        inactivityCheckTimer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let window else {
                // Window is gone - clear the timer to stop spam
                clearTimers()
                return
            }

            inactivityCheckCount += 1

            // CRITICAL: Stop timer if we're no longer the active preview
            // This prevents old timers from interfering with new previews
            if let coordinator = SharedPreviewWindowCoordinator.activeInstance,
               coordinator.appName != currentAppName
            {
                clearTimers()
                return
            }

            let currentMouseLocation = NSEvent.mouseLocation
            let windowFrame = window.frame

            // Skip check if window frame is not yet valid (still being set up)
            guard windowFrame.width > 0, windowFrame.height > 0 else { return }

            // CRITICAL: Skip first 3 checks (0.3s grace period) to allow window to fully appear
            // This prevents hide from triggering before user can see the preview
            guard inactivityCheckCount > 3 else { return }

            let isMouseOverOurDockIcon = checkIfMouseIsOverDockIcon()
            let isMouseOverAnyDockIcon = checkIfMouseIsOverAnyDockIcon()
            let isMouseInWindow = windowFrame.contains(currentMouseLocation)

            // CRITICAL: If mouse moved to a DIFFERENT dock icon, hide immediately
            // even if mouse is still technically in the preview window frame
            let isMouseOverDifferentDockIcon = isMouseOverAnyDockIcon && !isMouseOverOurDockIcon

            // PRIORITY ORDER:
            // Key insight: if dock observer detects ANY dock icon, mouse is at dock level.
            // Preview window frame may extend to dock area, but if mouse is at dock level,
            // user is interacting with dock, not preview.
            //
            // 1. If mouse is over ANY dock icon -> mouse is at dock level
            //    a. If over OUR dock icon -> stay visible, reset different icon counter
            //    b. If over DIFFERENT dock icon -> increment counter, hide after 2 consecutive checks
            //       (allows brief "travel" through other icons when moving to preview)
            // 2. If mouse is in preview window (and NOT at dock level) -> stay visible
            // 3. Otherwise -> hide
            if isMouseOverAnyDockIcon {
                // Mouse is at dock level
                if isMouseOverOurDockIcon {
                    // Over our dock icon - keep visible, reset counter
                    differentIconCount = 0
                    resetOpacityVisually()
                } else {
                    // Over a different dock icon - require 5 consecutive checks before hiding
                    // This allows ~500ms grace period for "travel" through other icons when moving to preview
                    differentIconCount += 1
                    if differentIconCount >= 5 {
                        if fadeOutTimer == nil, window.alphaValue == 1.0 {
                            startFadeOut()
                        }
                    }
                }
            } else if isMouseInWindow {
                // Mouse is in preview window and NOT at dock level - keep visible, reset counter
                differentIconCount = 0
                resetOpacityVisually()
            } else {
                // Mouse left both preview and dock area - hide
                differentIconCount = 0
                if fadeOutTimer == nil, window.alphaValue == 1.0 {
                    startFadeOut()
                }
            }
        }
    }

    private func checkIfMouseIsOverDockIcon() -> Bool {
        guard let activeDockObserver = DockObserver.activeInstance else { return false }
        guard let originalDockItem = currentDockItemElement else { return false }

        let currentAppReturnType = activeDockObserver.getDockItemAppStatusUnderMouse()
        guard let currentDockItem = currentAppReturnType.dockItemElement else { return false }

        return originalDockItem == currentDockItem
    }

    private func checkIfMouseIsOverAnyDockIcon() -> Bool {
        guard let activeDockObserver = DockObserver.activeInstance else { return false }
        let currentAppReturnType = activeDockObserver.getDockItemAppStatusUnderMouse()
        // If we got a dock item element, mouse is over some dock icon
        return currentAppReturnType.dockItemElement != nil
    }

    func resetOpacity() {
        resetOpacityVisually()
    }

    private func resetOpacityVisually() {
        guard !Defaults[.preventPreviewReentryDuringFadeOut] else { return }
        cancelFadeOut()
        setWindowOpacity(to: 1.0, duration: 0.2)
    }

    override func mouseEntered(with event: NSEvent) {
        resetOpacityVisually()
        SharedPreviewWindowCoordinator.activeInstance?.mouseIsWithinPreviewWindow = true
    }

    override func mouseExited(with event: NSEvent) {
        SharedPreviewWindowCoordinator.activeInstance?.mouseIsWithinPreviewWindow = false
    }

    private func startFadeOut() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard SharedPreviewWindowCoordinator.activeInstance?.windowSwitcherCoordinator.windowSwitcherActive == false else { return }
            guard dockPosition != .cmdTab else { return }

            guard let window, window.alphaValue > 0 else { return }

            cancelFadeOut()

            if fadeOutDuration == 0 {
                performHideWindow()
            } else {
                setWindowOpacity(to: 0.0, duration: fadeOutDuration)
                fadeOutTimer = Timer.scheduledTimer(withTimeInterval: fadeOutDuration, repeats: false) { [weak self] _ in
                    self?.performHideWindow()
                }
            }
        }
    }

    func cancelFadeOut() {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
    }

    private func setWindowOpacity(to value: CGFloat, duration: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            if window.alphaValue == value { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                window.animator().alphaValue = value
            }
        }
    }

    private func performHideWindow(preventLastAppClear: Bool = false) {
        print("HIDE_SOURCE[WindowDismissalContainer.performHideWindow]: Called for \(currentAppName)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // CRITICAL: Only hide if the current window is still showing OUR app
            // This prevents old timers from hiding newer previews for different apps
            guard let coordinator = SharedPreviewWindowCoordinator.activeInstance else { return }
            guard coordinator.appName == currentAppName else {
                print("HIDE_SOURCE[WindowDismissalContainer.performHideWindow]: SKIP - appName mismatch (current=\(coordinator.appName), expected=\(currentAppName))")
                // Invalidate our timer since we're no longer relevant
                clearTimers()
                return
            }

            coordinator.hideWindow()
        }
    }
}
