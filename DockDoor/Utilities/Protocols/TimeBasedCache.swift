import Foundation

/// Protocol for time-based caching with automatic staleness detection
/// Provides a unified interface for various caches used throughout the app
protocol TimeBasedCache {
    associatedtype Value

    /// The cached value
    var value: Value? { get set }

    /// When the cache was last updated
    var lastUpdateTime: Date? { get set }

    /// Time-to-live for the cache in seconds
    var ttl: TimeInterval { get }

    /// Whether the cache is stale and needs refresh
    var isStale: Bool { get }

    /// Clears the cache
    mutating func invalidate()

    /// Updates the cache with a new value
    mutating func update(with newValue: Value)
}

// MARK: - Default Implementations

extension TimeBasedCache {
    var isStale: Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) > ttl
    }

    mutating func invalidate() {
        value = nil
        lastUpdateTime = nil
    }

    mutating func update(with newValue: Value) {
        value = newValue
        lastUpdateTime = Date()
    }
}

// MARK: - Concrete Cache Implementations

/// Cache for windowless apps with configurable TTL
final class WindowlessAppsCache: TimeBasedCache {
    typealias Value = [WindowInfo]

    var value: [WindowInfo]?
    var lastUpdateTime: Date?
    let ttl: TimeInterval

    init(ttl: TimeInterval = WindowManagementConstants.windowlessRefreshMinInterval) {
        self.ttl = ttl
    }

    func invalidate() {
        value = nil
        lastUpdateTime = nil
    }

    func update(with newValue: [WindowInfo]) {
        value = newValue
        lastUpdateTime = Date()
    }
}

/// Cache for CGPoint dimensions with hash-based invalidation
final class DimensionsCache: TimeBasedCache {
    typealias Value = CGPoint

    var value: CGPoint?
    var lastUpdateTime: Date?
    var ttl: TimeInterval = .infinity // Dimensions cache uses hash-based invalidation

    private var lastWindowCount: Int = 0
    private var lastPanelSize: CGSize = .zero

    func shouldRefresh(windowCount: Int, panelSize: CGSize) -> Bool {
        value == nil || windowCount != lastWindowCount || panelSize != lastPanelSize
    }

    func update(with newValue: CGPoint, windowCount: Int, panelSize: CGSize) {
        value = newValue
        lastUpdateTime = Date()
        lastWindowCount = windowCount
        lastPanelSize = panelSize
    }

    func invalidate() {
        value = nil
        lastUpdateTime = nil
        lastWindowCount = 0
        lastPanelSize = .zero
    }

    func update(with newValue: CGPoint) {
        value = newValue
        lastUpdateTime = Date()
    }
}

/// Generic cache wrapper for any Equatable value
final class GenericCache<T>: TimeBasedCache {
    typealias Value = T

    var value: T?
    var lastUpdateTime: Date?
    let ttl: TimeInterval

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    func invalidate() {
        value = nil
        lastUpdateTime = nil
    }

    func update(with newValue: T) {
        value = newValue
        lastUpdateTime = Date()
    }
}
