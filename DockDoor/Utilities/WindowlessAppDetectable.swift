import AppKit
import Foundation

/// Protocol for detecting windowless applications
/// Enables protocol-oriented design and easier testing through dependency injection
protocol WindowlessAppDetectable {
    /// Checks if an application should be treated as windowless
    /// - Parameters:
    ///   - app: The running application to check
    ///   - existingWindows: Current list of known windows
    ///   - cgWindowList: Pre-fetched CG window list for performance
    /// - Returns: true if the app should be treated as windowless
    func isWindowlessApp(
        _ app: NSRunningApplication,
        existingWindows: [WindowInfo],
        cgWindowList: [[String: Any]]
    ) -> Bool

    /// Checks if a window is visible to the user
    /// - Parameters:
    ///   - window: The window to check
    ///   - cgWindowList: Pre-fetched CG window list for performance
    /// - Returns: true if the window is user-visible
    func isUserVisibleWindow(
        _ window: WindowInfo,
        cgWindowList: [[String: Any]]
    ) -> Bool
}

// MARK: - Default Implementation

/// Default implementation using ElectronAppRegistry and WindowManagementConstants
struct DefaultWindowlessAppDetector: WindowlessAppDetectable {
    func isWindowlessApp(
        _ app: NSRunningApplication,
        existingWindows: [WindowInfo],
        cgWindowList: [[String: Any]]
    ) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }

        // Use centralized ElectronAppRegistry for app detection
        guard ElectronAppRegistry.isElectronApp(bundleId) else { return false }

        // Recently launched apps - check if they have ANY windows
        let launchDate = app.launchDate ?? Date.distantPast
        let isRecentlyLaunched = Date().timeIntervalSince(launchDate) < WindowManagementConstants.recentlyLaunchedThreshold

        let allProcesses = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        var allWindows: [WindowInfo] = []
        for process in allProcesses {
            allWindows.append(contentsOf: existingWindows.filter { $0.app.processIdentifier == process.processIdentifier })
        }

        if isRecentlyLaunched {
            return allWindows.isEmpty
        }

        // Use pre-fetched window list for visibility checks
        let visibleWindows = allWindows.filter { !$0.isHidden && !$0.isMinimized && isUserVisibleWindow($0, cgWindowList: cgWindowList) }
        return visibleWindows.isEmpty
    }

    func isUserVisibleWindow(
        _ window: WindowInfo,
        cgWindowList: [[String: Any]]
    ) -> Bool {
        if let cgWindow = cgWindowList.first(where: { $0[kCGWindowNumber as String] as? CGWindowID == window.id }) {
            let layer = cgWindow[kCGWindowLayer as String] as? Int ?? 0
            let alpha = cgWindow[kCGWindowAlpha as String] as? Double ?? 1.0
            let bounds = cgWindow[kCGWindowBounds as String] as? [String: Any]
            let width = bounds?["Width"] as? Double ?? 0
            let height = bounds?["Height"] as? Double ?? 0

            // Skip non-layer-0, transparent, or too small windows
            if layer != 0 || alpha < WindowManagementConstants.minimumVisibleWindowAlpha ||
                width < WindowManagementConstants.minimumVisibleWindowDimension ||
                height < WindowManagementConstants.minimumVisibleWindowDimension
            {
                return false
            }
            return true
        }

        // Electron apps: if not found in CG window list, treat as non-visible
        if ElectronAppRegistry.isElectronApp(window.app.bundleIdentifier) {
            return false
        }

        return true
    }
}
