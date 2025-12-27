import Foundation

/// Protocol for unified index management across window coordinators
/// Consolidates the duplicate index tracking logic from WindowSwitcherStateManager and PreviewStateCoordinator
protocol IndexManaging: AnyObject {
    /// Current selected index
    var currentIndex: Int { get set }

    /// Total number of items
    var itemCount: Int { get }

    /// Whether there's an active search filter
    var hasActiveSearch: Bool { get }

    /// Filtered indices when search is active
    var filteredIndices: [Int] { get }

    /// Move to next item
    func cycleForward()

    /// Move to previous item
    func cycleBackward()

    /// Set index directly
    func setIndex(_ index: Int)

    /// Reset state
    func reset()
}

// MARK: - Default Implementations

extension IndexManaging {
    /// Safe index setter with bounds checking
    func setSafeIndex(_ index: Int) {
        guard itemCount > 0 else {
            currentIndex = -1
            return
        }
        currentIndex = max(0, min(index, itemCount - 1))
    }

    /// Get next index with wraparound
    func nextIndex(from current: Int, in count: Int) -> Int {
        guard count > 0 else { return -1 }
        if current < 0 { return 0 }
        return (current + 1) % count
    }

    /// Get previous index with wraparound
    func previousIndex(from current: Int, in count: Int) -> Int {
        guard count > 0 else { return -1 }
        if current < 0 { return count - 1 }
        return (current - 1 + count) % count
    }
}
