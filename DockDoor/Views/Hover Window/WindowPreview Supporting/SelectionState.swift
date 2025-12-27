import Combine
import SwiftUI

/// Lightweight ObservableObject for selection state only.
/// This is separate from PreviewStateCoordinator to avoid full view recreation on index changes.
/// Only publishes when selection-related state changes, preventing cursor disappearance
/// and unnecessary re-renders during hover interactions.
final class SelectionState: ObservableObject {
    @Published var currentIndex: Int = -1
    @Published var shouldScrollToIndex: Bool = true
    @Published var lastInputWasKeyboard: Bool = true

    /// Updates the selection index with optional scroll behavior
    /// - Parameters:
    ///   - index: The new index to select
    ///   - shouldScroll: Whether to scroll to the new index
    ///   - fromKeyboard: Whether the input was from keyboard (affects scroll behavior)
    func setIndex(_ index: Int, shouldScroll: Bool = true, fromKeyboard: Bool = true) {
        shouldScrollToIndex = shouldScroll
        lastInputWasKeyboard = fromKeyboard
        currentIndex = index
    }

    /// Resets selection state to initial values
    func reset() {
        currentIndex = -1
        shouldScrollToIndex = true
        lastInputWasKeyboard = true
    }
}
