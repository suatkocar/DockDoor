import AppKit
import Foundation

/// Protocol for window management operations
/// Enables dependency injection and easier testing
protocol WindowManaging {
    /// Gets all windows from all applications
    func getAllWindows(skipWindowlessApps: Bool) -> [WindowInfo]

    /// Gets windows for the frontmost application
    func getWindowsForFrontmostApp(from windows: [WindowInfo]) -> [WindowInfo]

    /// Filters windows by current space
    func filterWindowsByCurrentSpace(_ windows: [WindowInfo]) -> [WindowInfo]

    /// Manually refreshes the windowless apps cache
    func refreshWindowlessApps()

    /// Updates the cached window state
    func updateCachedWindowState(_ window: WindowInfo, updateAccessTime: Bool)

    /// The current cached windowless apps
    var cachedWindowlessApps: [WindowInfo] { get }
}

// MARK: - Default Implementation

/// Default window manager that wraps WindowUtil static methods
/// This allows for gradual migration to instance-based architecture
final class DefaultWindowManager: WindowManaging {
    static let shared = DefaultWindowManager()

    private init() {}

    func getAllWindows(skipWindowlessApps: Bool = false) -> [WindowInfo] {
        WindowUtil.getAllWindowsOfAllApps(skipWindowlessApps: skipWindowlessApps)
    }

    func getWindowsForFrontmostApp(from windows: [WindowInfo]) -> [WindowInfo] {
        WindowUtil.getWindowsForFrontmostApp(from: windows)
    }

    func filterWindowsByCurrentSpace(_ windows: [WindowInfo]) -> [WindowInfo] {
        WindowUtil.filterWindowsByCurrentSpaceSync(windows)
    }

    func refreshWindowlessApps() {
        WindowUtil.manuallyRefreshWindowlessApps()
    }

    func updateCachedWindowState(_ window: WindowInfo, updateAccessTime: Bool) {
        WindowUtil.updateCachedWindowState(window, updateAccessTime: updateAccessTime)
    }

    var cachedWindowlessApps: [WindowInfo] {
        WindowUtil.cachedWindowlessApps
    }
}

// MARK: - Mock Implementation for Testing

/// Mock window manager for unit testing
final class MockWindowManager: WindowManaging {
    var mockWindows: [WindowInfo] = []
    var mockWindowlessApps: [WindowInfo] = []

    func getAllWindows(skipWindowlessApps: Bool = false) -> [WindowInfo] {
        if skipWindowlessApps {
            return mockWindows.filter { !$0.isWindowlessApp }
        }
        return mockWindows
    }

    func getWindowsForFrontmostApp(from windows: [WindowInfo]) -> [WindowInfo] {
        guard let frontmostPid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return windows
        }
        return windows.filter { $0.app.processIdentifier == frontmostPid }
    }

    func filterWindowsByCurrentSpace(_ windows: [WindowInfo]) -> [WindowInfo] {
        // In mock, return all windows
        windows
    }

    func refreshWindowlessApps() {
        // No-op in mock
    }

    func updateCachedWindowState(_ window: WindowInfo, updateAccessTime: Bool) {
        // No-op in mock
    }

    var cachedWindowlessApps: [WindowInfo] {
        mockWindowlessApps
    }
}
