import Foundation

/// Centralized registry for Electron and Electron-like applications
/// These apps often have special window management behaviors that require custom handling
enum ElectronAppRegistry {
    // MARK: - Full Bundle Identifiers

    /// Apps that are known to have special window caching behavior
    /// These require exact bundle ID matching
    static let knownFullBundleIds: Set<String> = [
        "com.granola.app",
        "com.anthropic.claudefordesktop",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "com.spotify.client",
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.figma.Desktop",
        "com.electron.app",
    ]

    // MARK: - Bundle ID Prefixes

    /// Prefixes used to identify Electron/Chromium-based apps
    /// These apps often have invisible background windows that shouldn't prevent windowless status
    static let electronAppPrefixes: [String] = [
        // Core Electron identifiers
        "electron",
        "chromium",

        // Communication apps
        "anthropic",
        "claude",
        "slack",
        "discord",
        "telegram",
        "signal",
        "whatsapp",
        "teams",
        "zoom",
        "skype",
        "mattermost",
        "element",

        // Productivity apps
        "notion",
        "obsidian",
        "joplin",
        "logseq",
        "asana",
        "clickup",
        "linear",
        "miro",
        "canva",

        // Development tools
        "vscode",
        "cursor",
        "sublime",
        "atom",
        "intellij",
        "pycharm",
        "webstorm",
        "android-studio",
        "data-grip",
        "postman",
        "insomnia",
        "tableplus",
        "sequel-ace",
        "github",
        "gitkraken",
        "docker",

        // Design tools
        "figma",
        "sketch",

        // Media & Utilities
        "spotify",
        "dropbox",
        "1password",
        "bitwarden",

        // Browsers (Chromium-based)
        "brave",
        "vivaldi",
        "arc",

        // Other Electron apps
        "granola",
    ]

    /// Subset of prefixes for apps that need special tabbed window handling
    /// These apps should always keep their windows even if not in CG window list
    static let tabbedWindowExemptPrefixes: [String] = [
        "anthropic",
        "granola",
        "slack",
        "discord",
        "electron",
    ]

    // MARK: - Detection Methods

    /// Checks if a bundle identifier belongs to a known Electron/Chromium-based app
    /// - Parameter bundleId: The bundle identifier to check
    /// - Returns: true if the app is identified as Electron-like
    static func isElectronApp(_ bundleId: String?) -> Bool {
        guard let bundleId else { return false }

        // Check exact match first
        if knownFullBundleIds.contains(bundleId) {
            return true
        }

        // Check prefix match
        let lowercased = bundleId.lowercased()
        return electronAppPrefixes.contains { lowercased.contains($0) }
    }

    /// Checks if a bundle identifier belongs to an app exempt from tabbed window filtering
    /// - Parameter bundleId: The bundle identifier to check
    /// - Returns: true if the app should be exempt from tabbed window filtering
    static func isExemptFromTabbedWindowFiltering(_ bundleId: String?) -> Bool {
        guard let bundleId else { return false }
        let lowercased = bundleId.lowercased()
        return tabbedWindowExemptPrefixes.contains { lowercased.contains($0) }
    }

    /// Checks if a full bundle ID is in the known list (exact match)
    /// - Parameter bundleId: The bundle identifier to check
    /// - Returns: true if exact match found
    static func isKnownBundleId(_ bundleId: String?) -> Bool {
        guard let bundleId else { return false }
        return knownFullBundleIds.contains(bundleId)
    }
}
