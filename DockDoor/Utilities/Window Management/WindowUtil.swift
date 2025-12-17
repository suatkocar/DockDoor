import ApplicationServices
import Cocoa
import Defaults
import ScreenCaptureKit

let filteredBundleIdentifiers: [String] = ["com.apple.notificationcenterui"] // filters desktop widgets

/// Context for fetching windows - determines which settings to use
enum WindowFetchContext {
    case dockPreview
    case cmdTab
}

protocol WindowPropertiesProviding {
    var windowID: CGWindowID { get }
    var frame: CGRect { get }
    var title: String? { get }
    var owningApplicationBundleIdentifier: String? { get }
    var owningApplicationProcessID: pid_t? { get }
    var isOnScreen: Bool { get }
    var windowLayer: Int { get }
}

extension SCWindow: WindowPropertiesProviding {
    var owningApplicationBundleIdentifier: String? { owningApplication?.bundleIdentifier }
    var owningApplicationProcessID: pid_t? { owningApplication?.processID }
}

enum WindowAction: String, Hashable, CaseIterable, Defaults.Serializable {
    // Existing actions
    case quit
    case close
    case minimize
    case toggleFullScreen
    case hide
    case openNewWindow
    case maximize

    // Window positioning actions
    case fillLeftHalf
    case fillRightHalf
    case fillTopHalf
    case fillBottomHalf
    case fillTopLeftQuarter
    case fillTopRightQuarter
    case fillBottomLeftQuarter
    case fillBottomRightQuarter
    case center

    // No action
    case none

    var localizedName: String {
        switch self {
        case .quit:
            String(localized: "Quit App", comment: "Window action")
        case .close:
            String(localized: "Close Window", comment: "Window action")
        case .minimize:
            String(localized: "Minimize", comment: "Window action")
        case .toggleFullScreen:
            String(localized: "Toggle Full Screen", comment: "Window action")
        case .hide:
            String(localized: "Hide App", comment: "Window action")
        case .openNewWindow:
            String(localized: "Open New Window", comment: "Window action")
        case .maximize:
            String(localized: "Maximize", comment: "Window action")
        case .fillLeftHalf:
            String(localized: "Fill Left Half", comment: "Window action")
        case .fillRightHalf:
            String(localized: "Fill Right Half", comment: "Window action")
        case .fillTopHalf:
            String(localized: "Fill Top Half", comment: "Window action")
        case .fillBottomHalf:
            String(localized: "Fill Bottom Half", comment: "Window action")
        case .fillTopLeftQuarter:
            String(localized: "Fill Top Left", comment: "Window action")
        case .fillTopRightQuarter:
            String(localized: "Fill Top Right", comment: "Window action")
        case .fillBottomLeftQuarter:
            String(localized: "Fill Bottom Left", comment: "Window action")
        case .fillBottomRightQuarter:
            String(localized: "Fill Bottom Right", comment: "Window action")
        case .center:
            String(localized: "Center Window", comment: "Window action")
        case .none:
            String(localized: "No Action", comment: "Window action")
        }
    }

    var iconName: String {
        switch self {
        case .quit: "xmark.circle.fill"
        case .close: "xmark.square"
        case .minimize: "minus.circle"
        case .toggleFullScreen: "arrow.up.left.and.arrow.down.right"
        case .hide: "eye.slash"
        case .openNewWindow: "plus.rectangle.on.rectangle"
        case .maximize: "arrow.up.backward.and.arrow.down.forward"
        case .fillLeftHalf: "rectangle.lefthalf.filled"
        case .fillRightHalf: "rectangle.righthalf.filled"
        case .fillTopHalf: "rectangle.tophalf.filled"
        case .fillBottomHalf: "rectangle.bottomhalf.filled"
        case .fillTopLeftQuarter: "rectangle.split.2x2.fill"
        case .fillTopRightQuarter: "rectangle.split.2x2.fill"
        case .fillBottomLeftQuarter: "rectangle.split.2x2.fill"
        case .fillBottomRightQuarter: "rectangle.split.2x2.fill"
        case .center: "rectangle.center.inset.filled"
        case .none: "nosign"
        }
    }

    /// Actions that can be assigned to trackpad gestures
    static var gestureActions: [WindowAction] {
        [.none, .close, .minimize, .maximize, .toggleFullScreen, .hide, .quit,
         .fillLeftHalf, .fillRightHalf, .fillTopHalf, .fillBottomHalf,
         .fillTopLeftQuarter, .fillTopRightQuarter, .fillBottomLeftQuarter, .fillBottomRightQuarter, .center]
    }

    /// Result of performing a window action
    enum ActionResult {
        case dismissed
        case windowUpdated(WindowInfo)
        case windowRemoved
        case appWindowsRemoved(pid: pid_t)
        case noChange
    }

    /// Performs the action on the given window
    /// - Parameters:
    ///   - window: The window to perform the action on
    ///   - keepPreviewOnQuit: Whether to keep the preview open after quitting (removes app windows instead of dismissing)
    /// - Returns: The result indicating what happened
    func perform(on window: WindowInfo, keepPreviewOnQuit: Bool = false) -> ActionResult {
        switch self {
        case .quit:
            window.quit(force: NSEvent.modifierFlags.contains(.option))
            // Always return appWindowsRemoved - let appDidTerminate handler decide if switcher should close
            // This allows the switcher to stay open if there are other app windows
            return .appWindowsRemoved(pid: window.app.processIdentifier)

        case .close:
            window.close()
            return .windowRemoved

        case .minimize:
            var updatedWindow = window
            if updatedWindow.toggleMinimize() != nil {
                return .windowUpdated(updatedWindow)
            }
            return .noChange

        case .toggleFullScreen:
            var updatedWindow = window
            updatedWindow.toggleFullScreen()
            return .dismissed

        case .hide:
            var updatedWindow = window
            if updatedWindow.toggleHidden() != nil {
                return .windowUpdated(updatedWindow)
            }
            return .noChange

        case .openNewWindow:
            WindowUtil.openNewWindow(app: window.app)
            return .dismissed

        case .maximize:
            window.zoom()
            return .dismissed

        case .fillLeftHalf:
            window.fillLeftHalf()
            return .dismissed

        case .fillRightHalf:
            window.fillRightHalf()
            return .dismissed

        case .fillTopHalf:
            window.fillTopHalf()
            return .dismissed

        case .fillBottomHalf:
            window.fillBottomHalf()
            return .dismissed

        case .fillTopLeftQuarter:
            window.fillTopLeftQuarter()
            return .dismissed

        case .fillTopRightQuarter:
            window.fillTopRightQuarter()
            return .dismissed

        case .fillBottomLeftQuarter:
            window.fillBottomLeftQuarter()
            return .dismissed

        case .fillBottomRightQuarter:
            window.fillBottomRightQuarter()
            return .dismissed

        case .center:
            window.centerWindow()
            return .dismissed

        case .none:
            return .noChange
        }
    }
}

enum WindowUtil {
    private static let desktopSpaceWindowCacheManager = SpaceWindowCacheManager()

    static func isAppFiltered(_ app: NSRunningApplication) -> Bool {
        let filters = Defaults[.appNameFilters]
        guard !filters.isEmpty else { return false }

        let bundleId = app.bundleIdentifier ?? ""
        let appName = app.localizedName ?? ""

        // Check bundle ID (new format) or app name (legacy format)
        return filters.contains(bundleId) || filters.contains(where: { $0.caseInsensitiveCompare(appName) == .orderedSame })
    }

    // Track windows explicitly updated by bringWindowToFront to prevent observer duplication
    private static var timestampUpdates: [AXUIElement: Date] = [:]
    private static let updateTimestampLock = NSLock()
    private static let windowUpdateTimeWindow: TimeInterval = 1.5

    private static let captureError = NSError(
        domain: "WindowCaptureError",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Error encountered during image capture"]
    )
}

// MARK: - Cache Management

extension WindowUtil {
    static func clearWindowCache(for app: NSRunningApplication) {
        desktopSpaceWindowCacheManager.writeCache(pid: app.processIdentifier, windowSet: [])
    }

    static func updateWindowCache(for app: NSRunningApplication, update: @escaping (inout Set<WindowInfo>) -> Void) {
        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier, update: update)
    }

    static func updateWindowDateTime(element: AXUIElement, app: NSRunningApplication) {
        updateTimestampLock.lock()
        defer { updateTimestampLock.unlock() }

        // Check if this window was recently updated
        let now = Date()
        if let lastUpdate = timestampUpdates[element],
           now.timeIntervalSince(lastUpdate) < windowUpdateTimeWindow
        {
            // Clean up expired timestamp entries
            cleanupExpiredUpdates(currentTime: now)
            return // Skip update
        }

        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier) { windowSet in
            if let index = windowSet.firstIndex(where: { $0.axElement == element }) {
                var updatedWindow = windowSet[index]
                updatedWindow.lastAccessedTime = now
                windowSet.remove(at: index)
                windowSet.insert(updatedWindow)
            }
        }

        timestampUpdates[element] = now
    }

    /// Updates window timestamp optimistically and records breadcrumb for observer deduplication
    static func updateTimestampOptimistically(for windowInfo: WindowInfo) {
        let now = Date()
        desktopSpaceWindowCacheManager.updateCache(pid: windowInfo.app.processIdentifier) { windowSet in
            if let index = windowSet.firstIndex(where: { $0.axElement == windowInfo.axElement }) {
                var updatedWindow = windowSet[index]
                updatedWindow.lastAccessedTime = now
                windowSet.remove(at: index)
                windowSet.insert(updatedWindow)
            }
        }
    }

    /// Removes expired entries from timestamp tracking (must be called with lock held)
    static func cleanupExpiredUpdates(currentTime: Date) {
        timestampUpdates = timestampUpdates.filter { _, date in
            currentTime.timeIntervalSince(date) < windowUpdateTimeWindow
        }
    }

    static func updateCachedWindowState(_ windowInfo: WindowInfo, isMinimized: Bool? = nil, isHidden: Bool? = nil) {
        desktopSpaceWindowCacheManager.updateCache(pid: windowInfo.app.processIdentifier) { windowSet in
            if let existingIndex = windowSet.firstIndex(of: windowInfo) {
                var updatedWindow = windowSet[existingIndex]
                if let isMinimized {
                    updatedWindow.isMinimized = isMinimized
                }
                if let isHidden {
                    updatedWindow.isHidden = isHidden
                }
                windowSet.remove(at: existingIndex)
                windowSet.insert(updatedWindow)
            }
        }
    }
}

// MARK: - Window Capture

extension WindowUtil {
    static func captureWindowImage(window: SCWindow, forceRefresh: Bool = false) async throws -> CGImage {
        guard let pid = window.owningApplication?.processID else {
            throw captureError
        }

        return try await captureWindowImage(
            windowID: window.windowID,
            pid: pid,
            windowTitle: window.title,
            forceRefresh: forceRefresh
        )
    }

    static func captureWindowImage(windowID: CGWindowID, pid: pid_t, windowTitle: String? = nil, forceRefresh: Bool = false) async throws -> CGImage {
        // Check cache first if not forcing refresh
        if !forceRefresh {
            if let cachedWindow = desktopSpaceWindowCacheManager.readCache(pid: pid)
                .first(where: { $0.id == windowID && (windowTitle == nil || $0.windowName == windowTitle) }),
                let cachedImage = cachedWindow.image
            {
                let cacheLifespan = Defaults[.screenCaptureCacheLifespan]
                if Date().timeIntervalSince(cachedWindow.imageCapturedTime) <= cacheLifespan {
                    return cachedImage
                }
            }
        }

        var cgImage: CGImage
        let connectionID = CGSMainConnectionID()
        var windowIDUInt32 = UInt32(windowID)
        let qualityOption: CGSWindowCaptureOptions = (Defaults[.windowImageCaptureQuality] == .best) ? .bestResolution : .nominalResolution
        guard let capturedWindows = CGSHWCaptureWindowList(
            connectionID,
            &windowIDUInt32,
            1,
            [.ignoreGlobalClipShape, qualityOption]
        ) as? [CGImage],
            let capturedImage = capturedWindows.first
        else {
            throw captureError
        }
        cgImage = capturedImage

        // Only scale down if previewScale is greater than 1
        let previewScale = Int(Defaults[.windowPreviewImageScale])
        if previewScale > 1 {
            let newWidth = Int(cgImage.width) / previewScale
            let newHeight = Int(cgImage.height) / previewScale
            let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = cgImage.bitmapInfo
            guard let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                throw captureError
            }
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
            if let resizedImage = context.makeImage() {
                cgImage = resizedImage
            }
        }

        return cgImage
    }

    static func isValidElement(_ element: AXUIElement) -> Bool {
        do {
            let position = try element.position()
            let size = try element.size()
            if position != nil, size != nil {
                return true
            }
        } catch AxError.runtimeError {
            return false
        } catch {
            // Geometry check failed, fall through to AX windows list validation
        }

        do {
            if let pid = try element.pid() {
                let appElement = AXUIElementCreateApplication(pid)

                if let windows = try? appElement.windows() {
                    if let elementWindowId = try? element.cgWindowId() {
                        for window in windows {
                            if let windowId = try? window.cgWindowId(), windowId == elementWindowId {
                                return true
                            }
                        }
                    }

                    for window in windows {
                        if CFEqual(element, window) {
                            return true
                        }
                    }
                }
            }
        } catch {
            // Both checks failed
        }

        return false
    }

    static func findWindow(matchingWindow window: SCWindow, in axWindows: [AXUIElement]) -> AXUIElement? {
        if let matchedWindow = axWindows.first(where: { axWindow in
            (try? axWindow.cgWindowId()) == window.windowID
        }) {
            return matchedWindow
        }

        // Fallback metohd
        for axWindow in axWindows {
            if let windowTitle = window.title, let axTitle = try? axWindow.title(), isFuzzyMatch(windowTitle: windowTitle, axTitleString: axTitle) {
                return axWindow
            }

            if let axPosition = try? axWindow.position(), let axSize = try? axWindow.size(), axPosition != .zero, axSize != .zero {
                let positionThreshold: CGFloat = 10
                let sizeThreshold: CGFloat = 10

                let positionMatch = abs(axPosition.x - window.frame.origin.x) <= positionThreshold &&
                    abs(axPosition.y - window.frame.origin.y) <= positionThreshold

                let sizeMatch = abs(axSize.width - window.frame.size.width) <= sizeThreshold &&
                    abs(axSize.height - window.frame.size.height) <= sizeThreshold

                if positionMatch, sizeMatch {
                    return axWindow
                }
            }
        }

        return nil
    }

    static func isFuzzyMatch(windowTitle: String, axTitleString: String) -> Bool {
        let axTitleWords = axTitleString.lowercased().split(separator: " ")
        let windowTitleWords = windowTitle.lowercased().split(separator: " ")

        let matchingWords = axTitleWords.filter { windowTitleWords.contains($0) }
        let matchPercentage = Double(matchingWords.count) / Double(windowTitleWords.count)

        return matchPercentage >= 0.90 || matchPercentage.isNaN || axTitleString.lowercased().contains(windowTitle.lowercased())
    }

    static func findRunningApplicationByName(named applicationName: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.localizedName == applicationName }
    }
}

// MARK: - Window Discovery

extension WindowUtil {
    static func getAllWindowsOfAllApps() -> [WindowInfo] {
        var windows = desktopSpaceWindowCacheManager.getAllWindows()

        // Add windowless apps (like DeepL) - apps that are running but have no windows
        // This is done here (not in background) to avoid race conditions
        let windowlessApps = getWindowlessApps(existingWindows: windows)
        windows.append(contentsOf: windowlessApps)

        var filteredWindows = !Defaults[.includeHiddenWindowsInSwitcher]
            ? windows.filter { !$0.isHidden && !$0.isMinimized }
            : windows

        // Filter out apps that are in the user's filter list (applies immediately when filter changes)
        filteredWindows = filteredWindows.filter { !isAppFiltered($0.app) }

        // Filter out tabbed windows if showTabsAsWindows is disabled
        if !Defaults[.showTabsAsWindows] {
            filteredWindows = filterOutTabbedWindows(filteredWindows)
        }

        // Filter by frontmost app if enabled
        if Defaults[.limitSwitcherToFrontmostApp] {
            filteredWindows = getWindowsForFrontmostApp(from: filteredWindows)
        }

        return sortWindowsForSwitcher(filteredWindows)
    }

    /// Returns windowless app entries for running apps that have no windows
    /// Similar to AltTab's addWindowlessWindowIfNeeded() but called synchronously when switcher opens
    private static func getWindowlessApps(existingWindows: [WindowInfo]) -> [WindowInfo] {
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }

        // Get PIDs that already have windows
        let pidsWithWindows = Set(existingWindows.map(\.app.processIdentifier))

        // Get all window info from system to double-check
        let cgWindowList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var pidsWithSystemWindows = Set<pid_t>()
        for windowInfo in cgWindowList {
            guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }
            pidsWithSystemWindows.insert(pid)
        }

        var windowlessEntries: [WindowInfo] = []

        for app in runningApps {
            guard !isAppFiltered(app) else { continue }
            guard let bundleId = app.bundleIdentifier, !filteredBundleIdentifiers.contains(bundleId) else { continue }

            let pid = app.processIdentifier

            // Only add if app has NO windows in cache AND NO windows in system
            if !pidsWithWindows.contains(pid), !pidsWithSystemWindows.contains(pid) {
                let windowProvider = WindowlessAppProvider(app: app)

                let windowlessEntry = WindowInfo(
                    windowProvider: windowProvider,
                    app: app,
                    image: nil,
                    axElement: AXUIElementCreateApplication(pid),
                    appAxElement: AXUIElementCreateApplication(pid),
                    closeButton: nil,
                    lastAccessedTime: Date(),
                    creationTime: Date(),
                    imageCapturedTime: nil,
                    spaceID: nil,
                    isMinimized: false,
                    isHidden: app.isHidden
                )

                windowlessEntries.append(windowlessEntry)
            }
        }

        return windowlessEntries
    }

    private static func filterOutTabbedWindows(_ windows: [WindowInfo]) -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return windows
        }

        let visibleWindowIDs = Set(windowList.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })

        // Get current visible space IDs to check if window is in another space
        let currentSpaceIDs = Set(getVisibleSpaceIDs())

        return windows.filter { windowInfo in
            // Always keep minimized or hidden windows
            if windowInfo.isMinimized || windowInfo.isHidden {
                return true
            }

            // Keep windowless apps (id == 0) - these are placeholder entries for running apps with no windows
            if windowInfo.id == 0 {
                return true
            }

            // Keep windows that are visible on current screen
            if visibleWindowIDs.contains(windowInfo.id) {
                return true
            }

            // Keep windows that are in another space (not tabbed, just different space)
            let windowSpaceIDs = windowInfo.id.cgsSpaces()
            let isInOtherSpace = !windowSpaceIDs.isEmpty && windowSpaceIDs.allSatisfy { !currentSpaceIDs.contains($0) }
            if isInOtherSpace {
                return true
            }

            // Filter out tabbed windows (in current space but not visible)
            return false
        }
    }

    static func getWindowsForFrontmostApp(from windows: [WindowInfo]) -> [WindowInfo] {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return windows
        }

        return windows.filter { windowInfo in
            windowInfo.app.processIdentifier == frontmostApp.processIdentifier
        }
    }

    /// Filters windows to only include those in the current Space.
    /// Uses SCShareableContent to determine on-screen status (modern API).
    /// TODO: Update window observer to track window space in cache
    static func filterWindowsByCurrentSpace(_ windows: [WindowInfo]) async -> [WindowInfo] {
        let activeSpaceIDs = currentActiveSpaceIDs()

        // Use SCShareableContent to get on-screen window IDs
        let onScreenWindowIDs: Set<CGWindowID> = if let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) {
            Set(content.windows.map(\.windowID))
        } else {
            []
        }

        return windows.filter { windowInfo in
            let windowSpaces = Set(windowInfo.id.cgsSpaces().map { Int($0) })
            let isOnScreen = onScreenWindowIDs.contains(windowInfo.id)

            // For minimized/hidden windows, check if they belong to current space
            if windowInfo.isMinimized || windowInfo.isHidden {
                if !windowSpaces.isEmpty {
                    return !windowSpaces.isDisjoint(with: activeSpaceIDs)
                }
                if let spaceID = windowInfo.spaceID {
                    return activeSpaceIDs.contains(spaceID)
                }
                return true
            }

            // For normal windows, check space info
            if !windowSpaces.isEmpty {
                return !windowSpaces.isDisjoint(with: activeSpaceIDs)
            }

            // If no space info, check if window is on screen
            return isOnScreen
        }
    }

    static func getActiveWindows(of app: NSRunningApplication, context: WindowFetchContext = .dockPreview) async throws -> [WindowInfo] {
        if isAppFiltered(app) {
            purgeAppCache(with: app.processIdentifier)
            return []
        }

        var sckWindowIDs = Set<CGWindowID>()

        // Skip SCK if user has disabled image previews (compact mode only)
        if !Defaults[.disableImagePreview] {
            do {
                // Fetch SCK windows (visible windows only)
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

                // Build set of SCK window IDs
                sckWindowIDs = Set(content.windows.filter {
                    $0.owningApplication?.processID == app.processIdentifier
                }.map(\.windowID))

                // Process SCK windows
                for window in content.windows where window.owningApplication?.processID == app.processIdentifier {
                    await group.addTask { try await captureAndCacheWindowInfo(window: window, app: app) }
                }

                _ = try await group.waitForAll()
            } catch {
                // Screen recording permission not granted - fall back to AX-only discovery
            }
        }

        // Discover windows via AX (minimized, hidden, other spaces, SCK-missed, or all when compact mode)
        await discoverNonSCKWindowsViaAX(app: app, sckWindowIDs: sckWindowIDs)

        // Discover invisible windows using CGS private API (catches windows that SCK and AX miss)
        await discoverInvisibleWindows(for: app, excludeWindowIDs: sckWindowIDs)

        // Purify cache and return
        if let finalWindows = await WindowUtil.purifyAppCache(with: app.processIdentifier, removeAll: false) {
            guard !Defaults[.ignoreAppsWithSingleWindow] || finalWindows.count > 1 else { return [] }
            return sortWindows(finalWindows, for: context)
        }

        return []
    }

    private static func discoverNonSCKWindowsViaAX(app: NSRunningApplication, sckWindowIDs: Set<CGWindowID>) async {
        _ = await discoverWindowsViaAX(app: app, excludeWindowIDs: sckWindowIDs)
    }

    /// Discovers invisible/minimized windows using CGSCopyWindowsWithOptionsAndTags
    /// This catches windows that SCShareableContent and AX miss
    static func discoverInvisibleWindows(for app: NSRunningApplication, excludeWindowIDs: Set<CGWindowID> = []) async {
        let pid = app.processIdentifier
        let allSpaces = getAllSpaceIDs()
        guard !allSpaces.isEmpty else { return }

        let invisibleWindowIDs = windowIDsInSpaces(allSpaces, includeInvisible: true)

        let appAX = AXUIElementCreateApplication(pid)
        let cgCandidates = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: AnyObject]] ?? []

        for windowID in invisibleWindowIDs {
            guard !excludeWindowIDs.contains(windowID) else { continue }

            guard let cgEntry = cgCandidates.first(where: {
                ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == windowID &&
                    ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
            }) else { continue }

            let level = (cgEntry[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            guard level == 0 else { continue }

            let axWindows = AXUIElement.allWindows(pid, appElement: appAX)
            for axWin in axWindows {
                var axWindowID: CGWindowID = 0
                if _AXUIElementGetWindow(axWin, &axWindowID) == .success, axWindowID == windowID {
                    try? await captureAndCacheAXWindowInfo(
                        axWindow: axWin,
                        appAxElement: appAX,
                        app: app,
                        excludeWindowIDs: excludeWindowIDs
                    )
                    break
                }
            }
        }
    }

    /// Updates space info for all cached windows (like AltTab's updatesWindowSpace)
    /// Call this before showing window switcher to refresh space info
    static func updateSpaceInfoForAllWindows() {
        let allWindows = desktopSpaceWindowCacheManager.getAllWindows()
        for var window in allWindows {
            let spaceIds = window.id.cgsSpaces()
            window.spaceIDs = spaceIds
            window.isOnAllSpaces = spaceIds.count > 1
            if let firstSpace = spaceIds.first {
                window.spaceID = Int(firstSpace)
            }
            desktopSpaceWindowCacheManager.updateWindow(window)
        }
    }

    /// Discovers windows from ALL spaces for ALL running apps
    /// Call this before showing window switcher to ensure all windows are discovered
    /// For windows in other spaces (AX can't access), creates placeholder entries with app icon
    static func discoverAllWindowsFromAllSpaces() async {
        let allSpaces = getAllSpaceIDs()
        guard !allSpaces.isEmpty else { return }

        let allWindowIDs = windowIDsInSpaces(allSpaces, includeInvisible: true)
        let cgCandidates = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: AnyObject]] ?? []

        var pidToWindowInfo: [pid_t: [(windowID: CGWindowID, title: String?, bounds: CGRect?)]] = [:]

        for windowID in allWindowIDs {
            guard let cgEntry = cgCandidates.first(where: {
                ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == windowID
            }) else { continue }

            let level = (cgEntry[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            guard level == 0 else { continue }

            guard let pid = (cgEntry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value else { continue }

            let title = cgEntry[kCGWindowName as String] as? String
            var bounds: CGRect?
            if let boundsDict = cgEntry[kCGWindowBounds as String] as? [String: Any],
               let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            {
                bounds = rect
            }

            pidToWindowInfo[pid, default: []].append((windowID, title, bounds))
        }

        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        for app in runningApps {
            guard let windowInfos = pidToWindowInfo[app.processIdentifier], !windowInfos.isEmpty else { continue }
            guard !isAppFiltered(app) else { continue }

            let pid = app.processIdentifier
            let appAX = AXUIElementCreateApplication(pid)
            let axWindows = AXUIElement.allWindows(pid, appElement: appAX)

            // Get existing cached window IDs
            let cachedWindowIDs = Set(desktopSpaceWindowCacheManager.readCache(pid: pid).map(\.id))

            // Map AX windows to their IDs
            var axWindowMap: [CGWindowID: AXUIElement] = [:]
            for axWin in axWindows {
                var axWindowID: CGWindowID = 0
                if _AXUIElementGetWindow(axWin, &axWindowID) == .success {
                    axWindowMap[axWindowID] = axWin
                }
            }

            for (windowID, cgTitle, cgBounds) in windowInfos {
                // Skip if already cached
                if cachedWindowIDs.contains(windowID) { continue }

                if let axWin = axWindowMap[windowID] {
                    // AX accessible - use normal capture
                    try? await captureAndCacheAXWindowInfo(
                        axWindow: axWin,
                        appAxElement: appAX,
                        app: app,
                        excludeWindowIDs: cachedWindowIDs
                    )
                } else {
                    // AX not accessible (other space) - capture screenshot via CGS like AltTab does
                    let spaceIds = windowID.cgsSpaces()

                    // Capture screenshot using CGSHWCaptureWindowList (works across spaces)
                    var windowIDUInt32 = UInt32(windowID)
                    let screenshot: CGImage? = {
                        guard let capturedWindows = CGSHWCaptureWindowList(
                            CGSMainConnectionID(),
                            &windowIDUInt32,
                            1,
                            [.ignoreGlobalClipShape, .bestResolution]
                        ) as? [CGImage] else { return nil }
                        return capturedWindows.first
                    }()

                    let windowProvider = CGWindowInfoProvider(
                        windowID: windowID,
                        title: cgTitle ?? app.localizedName ?? "Window",
                        frame: cgBounds ?? .zero,
                        bundleID: app.bundleIdentifier,
                        pid: pid
                    )

                    let windowFromOtherSpace = WindowInfo(
                        windowProvider: windowProvider,
                        app: app,
                        image: screenshot, // Screenshot captured via CGS
                        axElement: appAX,
                        appAxElement: appAX,
                        closeButton: nil,
                        lastAccessedTime: Date(),
                        creationTime: Date(),
                        imageCapturedTime: screenshot != nil ? Date() : nil,
                        spaceID: spaceIds.first.map { Int($0) },
                        isMinimized: false,
                        isHidden: app.isHidden
                    )

                    desktopSpaceWindowCacheManager.updateCache(pid: pid) { windowSet in
                        windowSet.insert(windowFromOtherSpace)
                    }
                }
            }
        }

        // NOTE: Don't call addWindowlessApps() here - it causes race conditions
        // Windowless apps are handled in getAllWindowsOfAllApps() when switcher opens
    }

    /// Adds placeholder entries for running apps with no windows (like DeepL)
    /// Similar to AltTab's addWindowlessWindowIfNeeded() function
    /// AltTab ONLY does this for .regular apps, NOT .accessory apps
    private static func addWindowlessApps() async {
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }

        // Get all window info from system to check which apps actually have windows
        let cgWindowList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var pidsWithWindows = Set<pid_t>()
        for windowInfo in cgWindowList {
            guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }
            pidsWithWindows.insert(pid)
        }

        for app in runningApps {
            // Check both user filters and system filters
            guard !isAppFiltered(app) else { continue }
            guard let bundleId = app.bundleIdentifier, !filteredBundleIdentifiers.contains(bundleId) else { continue }

            let pid = app.processIdentifier
            let existingWindows = desktopSpaceWindowCacheManager.readCache(pid: pid)

            // Only add windowless placeholder if:
            // 1. App has no windows in cache AND
            // 2. App has no windows in system (CGWindowList)
            // This prevents adding placeholders for apps that actually have windows
            let hasWindowsInSystem = pidsWithWindows.contains(pid)
            if existingWindows.isEmpty, !hasWindowsInSystem {
                let windowProvider = WindowlessAppProvider(app: app)

                let windowlessEntry = WindowInfo(
                    windowProvider: windowProvider,
                    app: app,
                    image: nil, // Will show app icon
                    axElement: AXUIElementCreateApplication(pid),
                    appAxElement: AXUIElementCreateApplication(pid),
                    closeButton: nil,
                    lastAccessedTime: Date(),
                    creationTime: Date(),
                    imageCapturedTime: nil,
                    spaceID: nil,
                    isMinimized: false,
                    isHidden: app.isHidden
                )

                desktopSpaceWindowCacheManager.updateCache(pid: pid) { windowSet in
                    windowSet.insert(windowlessEntry)
                }
            }
        }
    }

    /// A simple WindowPropertiesProviding implementation for CGS-discovered windows
    struct CGWindowInfoProvider: WindowPropertiesProviding {
        let windowID: CGWindowID
        let title: String?
        let frame: CGRect
        let owningApplicationBundleIdentifier: String?
        let owningApplicationProcessID: pid_t?
        let isOnScreen: Bool
        let windowLayer: Int

        init(windowID: CGWindowID, title: String?, frame: CGRect, bundleID: String? = nil, pid: pid_t? = nil) {
            self.windowID = windowID
            self.title = title
            self.frame = frame
            owningApplicationBundleIdentifier = bundleID
            owningApplicationProcessID = pid
            isOnScreen = false // Window is in another space
            windowLayer = 0
        }
    }

    /// A WindowPropertiesProviding implementation for windowless apps (like DeepL, menu bar apps)
    /// These apps are running but have no visible windows - we show just the app icon
    struct WindowlessAppProvider: WindowPropertiesProviding {
        let windowID: CGWindowID
        let title: String?
        let frame: CGRect
        let owningApplicationBundleIdentifier: String?
        let owningApplicationProcessID: pid_t?
        let isOnScreen: Bool
        let windowLayer: Int

        init(app: NSRunningApplication) {
            // Use a special windowID (0) to indicate windowless app
            windowID = 0
            title = app.localizedName
            frame = .zero
            owningApplicationBundleIdentifier = app.bundleIdentifier
            owningApplicationProcessID = app.processIdentifier
            isOnScreen = false
            windowLayer = 0
        }
    }

    static func discoverWindowsViaAX(
        app: NSRunningApplication,
        excludeWindowIDs: Set<CGWindowID> = []
    ) async -> Int {
        let pid = app.processIdentifier

        guard let bundleId = app.bundleIdentifier, !filteredBundleIdentifiers.contains(bundleId) else {
            purgeAppCache(with: pid)
            return 0
        }

        if isAppFiltered(app) {
            purgeAppCache(with: pid)
            return 0
        }

        let appAX = AXUIElementCreateApplication(pid)
        let axWindows = AXUIElement.allWindows(pid, appElement: appAX)
        guard !axWindows.isEmpty else { return 0 }

        let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

        for axWin in axWindows {
            await group.addTask {
                try? await captureAndCacheAXWindowInfo(
                    axWindow: axWin,
                    appAxElement: appAX,
                    app: app,
                    excludeWindowIDs: excludeWindowIDs
                )
            }
        }

        _ = try? await group.waitForAll()

        return axWindows.count
    }

    static func updateNewWindowsForApp(_ app: NSRunningApplication) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

            let appWindows = content.windows.filter { window in
                guard let scApp = window.owningApplication else { return false }
                return scApp.processID == app.processIdentifier
            }

            for window in appWindows {
                await group.addTask {
                    try? await captureAndCacheWindowInfo(window: window, app: app)
                }
            }

            _ = try await group.waitForAll()

        } catch {
            print("Error updating windows for \(app.localizedName ?? "unknown app"): \(error)")
        }

        // AX fallback: discover windows that SCK didn't report (e.g., some Adobe apps)
        await discoverNewWindowsViaAXFallback(app: app)
        // Ensure AX-fallback windows get fresh images too
        await refreshAXFallbackWindowImages(for: app.processIdentifier)
    }

    // MARK: - AX Fallback Discovery

    /// Discovers and caches windows via AX + CGS when SCK misses them (e.g., certain Adobe apps)
    private static func discoverNewWindowsViaAXFallback(app: NSRunningApplication) async {
        _ = await discoverWindowsViaAX(app: app)
    }

    static func updateAllWindowsInCurrentSpace() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            var processedPIDs = Set<pid_t>()
            let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

            for window in content.windows {
                guard let scApp = window.owningApplication,
                      !filteredBundleIdentifiers.contains(scApp.bundleIdentifier)
                else { continue }

                if let nsApp = NSRunningApplication(processIdentifier: scApp.processID) {
                    processedPIDs.insert(nsApp.processIdentifier)
                    await group.addTask {
                        try? await captureAndCacheWindowInfo(window: window, app: nsApp)
                    }
                }
            }
            _ = try await group.waitForAll()

            // After processing windows, purify the cache for each app that had windows in the current space
            for pid in processedPIDs {
                _ = await purifyAppCache(with: pid, removeAll: false)
                // Refresh images for AX-fallback windows (not covered by SCK)
                await refreshAXFallbackWindowImages(for: pid)
            }

        } catch {
            print("Error updating windows: \(error)")
        }
    }

    /// Refresh images for windows discovered via AX fallback (no SCWindow available)
    private static func refreshAXFallbackWindowImages(for pid: pid_t) async {
        let windows = desktopSpaceWindowCacheManager.readCache(pid: pid)
        guard !windows.isEmpty else { return }

        let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

        for window in windows where window.scWindow == nil {
            // Skip windowless apps - they don't have real windows to refresh
            if window.isWindowlessApp {
                continue
            }

            // Skip invalid AX elements but DON'T remove from cache
            // The window might be temporarily inaccessible (dialog, sheet, etc.)
            // Let purifyAppCache handle removal if window truly doesn't exist
            if !isValidElement(window.axElement) {
                continue
            }

            await group.addTask {
                if let image = try? await captureWindowImage(windowID: window.id, pid: pid, windowTitle: window.windowName) {
                    var updated = window
                    updated.image = image
                    updated.spaceID = window.id.cgsSpaces().first.map { Int($0) }
                    updateDesktopSpaceWindowCache(with: updated)
                }
            }
        }

        _ = try? await group.waitForAll()
    }

    static func captureAndCacheWindowInfo(window: SCWindow, app: NSRunningApplication) async throws {
        let windowID = window.windowID

        guard window.owningApplication != nil,
              window.isOnScreen,
              window.windowLayer == 0,
              window.frame.size.width >= 100,
              window.frame.size.height >= 100
        else { return }

        guard let bundleId = app.bundleIdentifier else {
            purgeAppCache(with: app.processIdentifier)
            return
        }

        if filteredBundleIdentifiers.contains(bundleId) {
            purgeAppCache(with: app.processIdentifier)
            return
        }

        if isAppFiltered(app) {
            purgeAppCache(with: app.processIdentifier)
            return
        }

        if let windowTitle = window.title {
            let windowTitleFilters = Defaults[.windowTitleFilters]
            if !windowTitleFilters.isEmpty {
                for filter in windowTitleFilters {
                    if windowTitle.lowercased().contains(filter.lowercased()) {
                        removeWindowFromDesktopSpaceCache(with: windowID, in: app.processIdentifier)
                        return
                    }
                }
            }
        }

        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier) { windowSet in
            windowSet = windowSet.filter { cachedWindow in
                if let cachedTitle = cachedWindow.windowName {
                    for filter in Defaults[.windowTitleFilters] {
                        if cachedTitle.lowercased().contains(filter.lowercased()) {
                            return false
                        }
                    }
                }
                return true
            }
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        guard let axWindows = try? appElement.windows(), !axWindows.isEmpty else {
            return
        }

        guard let windowRef = findWindow(matchingWindow: window, in: axWindows) else {
            return
        }

        let closeButton = try? windowRef.closeButton()
        let minimizeButton = try? windowRef.minimizeButton()
        let minimizedState = (try? windowRef.isMinimized()) ?? false
        let hiddenState = app.isHidden
        let shouldWindowBeCaptured = (closeButton != nil) || (minimizeButton != nil)

        if shouldWindowBeCaptured {
            var windowInfo = WindowInfo(
                windowProvider: window,
                app: app,
                image: nil,
                axElement: windowRef,
                appAxElement: appElement,
                closeButton: closeButton,
                lastAccessedTime: Date.now,
                spaceID: window.windowID.cgsSpaces().first.map { Int($0) },
                isMinimized: minimizedState,
                isHidden: hiddenState
            )

            if let image = try? await captureWindowImage(window: window) {
                windowInfo.image = image
                windowInfo.imageCapturedTime = Date()
            }
            updateDesktopSpaceWindowCache(with: windowInfo)
        }
    }

    static func captureAndCacheAXWindowInfo(
        axWindow: AXUIElement,
        appAxElement: AXUIElement,
        app: NSRunningApplication,
        excludeWindowIDs: Set<CGWindowID>
    ) async throws {
        let pid = app.processIdentifier

        guard isValidAXWindowCandidate(axWindow) else { return }

        let cgCandidates = getCGWindowCandidates(for: pid)
        let usedIDs = Set<CGWindowID>(desktopSpaceWindowCacheManager.readCache(pid: pid).map(\.id))

        var cgID: CGWindowID = 0
        if _AXUIElementGetWindow(axWindow, &cgID) == .success, cgID != 0 {
        } else if let mapped = mapAXToCG(axWindow: axWindow, candidates: cgCandidates, excluding: usedIDs) {
            cgID = mapped
        } else {
            return
        }

        guard !excludeWindowIDs.contains(cgID), !usedIDs.contains(cgID) else { return }

        guard isAtLeastNormalLevel(cgID) else { return }

        let titleFilters = Defaults[.windowTitleFilters]
        if !titleFilters.isEmpty {
            let cgTitle = cgID.cgsTitle() ?? ""
            if titleFilters.contains(where: { cgTitle.lowercased().contains($0.lowercased()) }) {
                return
            }
        }

        guard isValidCGWindowCandidate(cgID, in: cgCandidates) else { return }

        guard let cgEntry = findCGEntry(for: cgID, in: cgCandidates) else { return }

        let activeSpaceIDs = currentActiveSpaceIDs()
        guard shouldAcceptWindow(
            axWindow: axWindow,
            windowID: cgID,
            cgEntry: cgEntry,
            app: app,
            activeSpaceIDs: activeSpaceIDs,
            scBacked: false
        ) else { return }

        // Try AX title first (works without screen recording permission), fall back to CGS title
        let windowTitle = (try? axWindow.title()) ?? cgID.cgsTitle()
        let minimizedState = (try? axWindow.isMinimized()) ?? false
        let hiddenState = app.isHidden

        var info = WindowInfo(
            windowProvider: AXFallbackProvider(cgID: cgID),
            app: app,
            image: nil,
            axElement: axWindow,
            appAxElement: appAxElement,
            closeButton: try? axWindow.closeButton(),
            lastAccessedTime: Date(),
            spaceID: cgID.cgsSpaces().first.map { Int($0) },
            isMinimized: minimizedState,
            isHidden: hiddenState
        )
        info.windowName = windowTitle

        if let image = try? await captureWindowImage(windowID: cgID, pid: pid, windowTitle: windowTitle) {
            info.image = image
            info.imageCapturedTime = Date()
        }

        updateDesktopSpaceWindowCache(with: info)
    }

    static func updateDesktopSpaceWindowCache(with windowInfo: WindowInfo) {
        desktopSpaceWindowCacheManager.updateCache(pid: windowInfo.app.processIdentifier) { windowSet in
            if let matchingWindow = windowSet.first(where: { $0.axElement == windowInfo.axElement }) {
                var matchingWindowCopy = matchingWindow
                matchingWindowCopy.windowName = windowInfo.windowName
                matchingWindowCopy.image = windowInfo.image
                matchingWindowCopy.imageCapturedTime = windowInfo.imageCapturedTime
                matchingWindowCopy.spaceID = windowInfo.spaceID
                matchingWindowCopy.isMinimized = windowInfo.isMinimized
                matchingWindowCopy.isHidden = windowInfo.isHidden

                windowSet.remove(matchingWindow)
                windowSet.insert(matchingWindowCopy)
            } else {
                windowSet.insert(windowInfo)
            }
        }
    }

    static func removeWindowFromDesktopSpaceCache(with windowId: CGWindowID, in pid: pid_t) {
        desktopSpaceWindowCacheManager.removeFromCache(pid: pid, windowId: windowId)
    }

    static func removeWindowFromCache(with element: AXUIElement, in pid: pid_t) {
        if let windowId = try? element.cgWindowId() {
            removeWindowFromDesktopSpaceCache(with: windowId, in: pid)
        }
    }

    static func purifyAppCache(with pid: pid_t, removeAll: Bool) async -> Set<WindowInfo>? {
        if removeAll {
            desktopSpaceWindowCacheManager.writeCache(pid: pid, windowSet: [])
            return nil
        } else {
            let existingWindowsSet = desktopSpaceWindowCacheManager.readCache(pid: pid)
            if existingWindowsSet.isEmpty {
                return nil
            }

            // Get all window IDs that exist in the system (across all spaces)
            let allSpaces = getAllSpaceIDs()
            let systemWindowIDs = Set(windowIDsInSpaces(allSpaces, includeInvisible: true))

            var purifiedSet = existingWindowsSet
            for window in existingWindowsSet {
                // Windowless apps (id == 0) are placeholders - check if app is still valid and not filtered
                if window.isWindowlessApp {
                    // Remove windowless app if the app is filtered or terminated
                    if isAppFiltered(window.app) || window.app.isTerminated {
                        purifiedSet.remove(window)
                        desktopSpaceWindowCacheManager.removeFromCache(pid: pid, windowId: window.id)
                    }
                    continue
                }

                // Check if window still exists in the system (works across spaces)
                let existsInSystem = systemWindowIDs.contains(window.id)

                if !existsInSystem {
                    // Window no longer exists, remove it
                    purifiedSet.remove(window)
                    desktopSpaceWindowCacheManager.removeFromCache(pid: pid, windowId: window.id)
                } else if !isValidElement(window.axElement) {
                    // Window exists but AX can't access it - likely in another space
                    // Update space info but keep in cache
                    var updatedWindow = window
                    updatedWindow.spaceIDs = window.id.cgsSpaces()
                    updatedWindow.isOnAllSpaces = updatedWindow.spaceIDs.count > 1
                    if let firstSpace = updatedWindow.spaceIDs.first {
                        updatedWindow.spaceID = Int(firstSpace)
                    }
                    purifiedSet.remove(window)
                    purifiedSet.insert(updatedWindow)
                    desktopSpaceWindowCacheManager.updateWindow(updatedWindow)
                }
            }
            return purifiedSet
        }
    }

    static func purgeAppCache(with pid: pid_t) {
        desktopSpaceWindowCacheManager.writeCache(pid: pid, windowSet: [])
    }

    /// Checks if the frontmost application is fullscreen and in the blacklist
    static func shouldIgnoreKeybindForFrontmostApp() -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        // Check if the app is in fullscreen mode
        let isFullscreen = isAppInFullscreen(frontmostApp)

        // Check if the app is in the blacklist
        let appName = frontmostApp.localizedName ?? ""
        let bundleIdentifier = frontmostApp.bundleIdentifier ?? ""
        let blacklist = Defaults[.fullscreenAppBlacklist]

        let isInBlacklist = blacklist.contains { blacklistEntry in
            appName.lowercased().contains(blacklistEntry.lowercased()) ||
                bundleIdentifier.lowercased().contains(blacklistEntry.lowercased())
        }

        return isFullscreen && isInBlacklist
    }

    /// Checks if the given application is currently in fullscreen mode
    static func isAppInFullscreen(_ app: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Try to get the app's windows
        guard let windows = try? appElement.windows() else {
            return false
        }

        // Check if any window is in fullscreen mode
        for window in windows {
            if let isFullscreen = try? window.isFullscreen(), isFullscreen {
                return true
            }
        }

        return false
    }
}

// MARK: - Window Sorting

extension WindowUtil {
    /// Centralized sorting for dock preview and cmd+tab contexts (single app windows)
    static func sortWindows(_ windows: Set<WindowInfo>, for context: WindowFetchContext) -> [WindowInfo] {
        let sortOrder: WindowPreviewSortOrder = switch context {
        case .dockPreview:
            Defaults[.windowPreviewSortOrder]
        case .cmdTab:
            Defaults[.cmdTabSortOrder]
        }

        return sortWindowsWithOptions(Array(windows), sortOrder: sortOrder)
    }

    /// Centralized sorting for window switcher context (all apps windows)
    static func sortWindowsForSwitcher(_ windows: [WindowInfo]) -> [WindowInfo] {
        sortWindowsWithOptions(windows, sortOrder: Defaults[.windowSwitcherSortOrder])
    }

    /// Core sorting logic with configurable options
    private static func sortWindowsWithOptions(
        _ windows: [WindowInfo],
        sortOrder: WindowPreviewSortOrder
    ) -> [WindowInfo] {
        var sortedWindows: [WindowInfo]

            // Apply primary sort order
            = switch sortOrder
        {
        case .recentlyUsed:
            windows.sorted { $0.lastAccessedTime > $1.lastAccessedTime }
        case .creationOrder:
            windows.sorted { $0.creationTime < $1.creationTime }
        case .alphabeticalByTitle:
            windows.sorted { ($0.windowName ?? "").localizedCaseInsensitiveCompare($1.windowName ?? "") == .orderedAscending }
        case .alphabeticalByAppName:
            // Group by app name, then sort within groups by recently used
            windows.sorted { first, second in
                let firstName = first.app.localizedName ?? ""
                let secondName = second.app.localizedName ?? ""
                if firstName != secondName {
                    return firstName.localizedCaseInsensitiveCompare(secondName) == .orderedAscending
                }
                // Within same app, sort by recently used
                return first.lastAccessedTime > second.lastAccessedTime
            }
        }

        // Optionally move minimized/hidden windows to the end (global setting)
        if Defaults[.sortMinimizedToEnd] {
            let (visible, minimizedOrHidden) = sortedWindows.reduce(into: ([WindowInfo](), [WindowInfo]())) { result, window in
                if window.isMinimized || window.isHidden {
                    result.1.append(window)
                } else {
                    result.0.append(window)
                }
            }
            sortedWindows = visible + minimizedOrHidden
        }

        return sortedWindows
    }
}

// MARK: - Window Actions

extension WindowUtil {
    static func openNewWindow(app: NSRunningApplication) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x2D, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.postToPid(app.processIdentifier)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x2D, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.postToPid(app.processIdentifier)
    }
}

// MARK: - Private Helper Methods

extension WindowUtil {
    /// Makes a window key by posting raw event bytes to the Window Server
    /// Ported from https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468
    static func makeKeyWindow(_ psn: inout ProcessSerialNumber, windowID: CGWindowID) {
        var bytes = [UInt8](repeating: 0, count: 0xF8)
        bytes[0x04] = 0xF8
        bytes[0x3A] = 0x10
        var wid = UInt32(windowID)
        memcpy(&bytes[0x3C], &wid, MemoryLayout<UInt32>.size)
        memset(&bytes[0x20], 0xFF, 0x10)
        bytes[0x08] = 0x01
        _ = SLPSPostEventRecordTo(&psn, &bytes)
        bytes[0x08] = 0x02
        _ = SLPSPostEventRecordTo(&psn, &bytes)
    }
}
