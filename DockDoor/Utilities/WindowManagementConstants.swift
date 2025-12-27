import Foundation

/// Centralized constants for window management operations
/// Eliminates magic numbers and provides clear documentation for each value
enum WindowManagementConstants {
    // MARK: - Cache & Refresh Intervals

    /// Minimum interval between windowless app cache refreshes (seconds)
    /// Prevents excessive system calls while keeping cache reasonably fresh
    static let windowlessRefreshMinInterval: TimeInterval = 1.0

    /// Throttle interval for space refresh operations (seconds)
    /// Space API calls are expensive, this limits their frequency
    static let spaceRefreshThrottleInterval: TimeInterval = 0.5

    /// Throttle interval for full window list updates (seconds)
    /// Used for background discovery of windows across all spaces
    static let updateAllWindowsThrottleInterval: TimeInterval = 60.0

    // MARK: - App Launch Detection

    /// Time threshold to consider an app as "recently launched" (seconds)
    /// Recently launched apps may not have created their windows yet
    static let recentlyLaunchedThreshold: TimeInterval = 5.0

    // MARK: - Window Visibility Thresholds

    /// Minimum window dimension to be considered visible (pixels)
    /// Windows smaller than this are likely invisible helper windows
    static let minimumVisibleWindowDimension: Double = 100.0

    /// Minimum alpha value for a window to be considered visible
    /// Windows with lower alpha are effectively transparent
    static let minimumVisibleWindowAlpha: Double = 0.1

    // MARK: - Preview Sizing

    /// Default maximum width for window previews (pixels)
    static let defaultPreviewMaxWidth: CGFloat = 300.0

    /// Default maximum height for window previews (pixels)
    static let defaultPreviewMaxHeight: CGFloat = 300.0

    /// Minimum preview thickness (pixels)
    /// Used when calculating dynamic preview sizes
    static let minPreviewThickness: CGFloat = 200.0

    /// Maximum preview thickness (pixels)
    /// Upper bound for dynamic preview sizing
    static let maxPreviewThickness: CGFloat = 400.0

    /// Maximum aspect ratio for preview thumbnails
    /// Prevents extremely wide or tall previews
    static let maxPreviewAspectRatio: CGFloat = 1.5

    // MARK: - Layout Constants

    /// Maximum percentage of screen size for card frame dimensions
    static let cardMaxFrameScreenPercentage: CGFloat = 0.75
}
