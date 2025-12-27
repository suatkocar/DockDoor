import Cocoa
import SwiftUI

struct TrackpadGestureModifier: ViewModifier {
    var onSwipeUp: () -> Void
    var onSwipeDown: () -> Void
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
            }
            .background(
                TrackpadEventMonitor(
                    isActive: $isHovering,
                    onSwipeUp: onSwipeUp,
                    onSwipeDown: onSwipeDown,
                    onSwipeLeft: onSwipeLeft,
                    onSwipeRight: onSwipeRight
                )
                .frame(width: 0, height: 0)
            )
    }
}

struct TrackpadEventMonitor: NSViewRepresentable {
    @Binding var isActive: Bool
    var onSwipeUp: () -> Void
    var onSwipeDown: () -> Void
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // Set up event monitor when view is added to hierarchy
        context.coordinator.setupMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isActive = isActive
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        // Remove event monitor when view is removed from hierarchy
        // This fixes scroll blocking in Settings when switcher is hidden
        coordinator.removeMonitor()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSwipeUp: onSwipeUp,
            onSwipeDown: onSwipeDown,
            onSwipeLeft: onSwipeLeft,
            onSwipeRight: onSwipeRight
        )
    }

    class Coordinator {
        var isActive = false
        var onSwipeUp: () -> Void
        var onSwipeDown: () -> Void
        var onSwipeLeft: () -> Void
        var onSwipeRight: () -> Void

        private var scrollMonitor: Any?
        private var cumulativeScrollX: CGFloat = 0
        private var cumulativeScrollY: CGFloat = 0
        private var isScrolling = false
        private var isNaturalScrolling = false
        private var scrollEndTimer: Timer?

        private static var instanceCount = 0
        private let instanceId: Int

        // Central registry of all active coordinators for explicit cleanup
        private static var activeCoordinators: [Int: Coordinator] = [:]

        /// Remove all active monitors - call this when hiding the switcher window
        static func removeAllMonitors() {
            for (_, coordinator) in activeCoordinators {
                coordinator.removeMonitor()
            }
        }

        init(
            onSwipeUp: @escaping () -> Void,
            onSwipeDown: @escaping () -> Void,
            onSwipeLeft: @escaping () -> Void,
            onSwipeRight: @escaping () -> Void
        ) {
            Self.instanceCount += 1
            instanceId = Self.instanceCount
            self.onSwipeUp = onSwipeUp
            self.onSwipeDown = onSwipeDown
            self.onSwipeLeft = onSwipeLeft
            self.onSwipeRight = onSwipeRight
            // Don't set up monitor here - wait for view to be added to hierarchy
        }

        deinit {
            removeMonitor()
        }

        /// Remove event monitor - called when view is removed from hierarchy
        func removeMonitor() {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
                scrollMonitor = nil
            }
            scrollEndTimer?.invalidate()
            scrollEndTimer = nil
            // Unregister from central registry
            Self.activeCoordinators.removeValue(forKey: instanceId)
        }

        /// Set up event monitor - called when view is added to hierarchy
        func setupMonitor() {
            guard scrollMonitor == nil else { return }
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self else { return event }
                return handleScroll(event)
            }
            // Register in central registry for explicit cleanup
            Self.activeCoordinators[instanceId] = self
        }

        private func handleScroll(_ event: NSEvent) -> NSEvent? {
            guard isActive else {
                print(" [handleScroll] Not active, ignoring scroll")
                return event
            }
            // IMPORTANT: Pass through non-trackpad events to allow scrolling in other windows
            guard event.hasPreciseScrollingDeltas else {
                print(" [handleScroll] Not precise scrolling, ignoring")
                return event
            }

            switch event.phase {
            case .began:
                cumulativeScrollX = 0
                cumulativeScrollY = 0
                isScrolling = true
                isNaturalScrolling = event.isDirectionInvertedFromDevice
                scrollEndTimer?.invalidate()

            case .changed:
                cumulativeScrollX += event.scrollingDeltaX
                cumulativeScrollY += event.scrollingDeltaY

            case .ended:
                finishScroll()

            case .cancelled:
                cumulativeScrollX = 0
                cumulativeScrollY = 0
                isScrolling = false

            default:
                break
            }

            scrollEndTimer?.invalidate()
            scrollEndTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                self?.finishScroll()
            }

            return nil
        }

        private func finishScroll() {
            guard isScrolling else { return }
            isScrolling = false

            let minDelta: CGFloat = 50

            let normalizedY = isNaturalScrolling ? -cumulativeScrollY : cumulativeScrollY

            print("🔍 [finishScroll] Final scroll: X=\(cumulativeScrollX), Y=\(cumulativeScrollY), normalizedY=\(normalizedY)")

            if abs(cumulativeScrollY) > abs(cumulativeScrollX), abs(cumulativeScrollY) > minDelta {
                if cumulativeScrollY < 0 {
                    print("🔍 [finishScroll] Triggering swipe DOWN")
                    DispatchQueue.main.async { self.onSwipeDown() }
                } else {
                    print("🔍 [finishScroll] Triggering swipe UP")
                    DispatchQueue.main.async { self.onSwipeUp() }
                }
            } else if abs(cumulativeScrollX) > abs(cumulativeScrollY), abs(cumulativeScrollX) > minDelta {
                if cumulativeScrollX > 0 {
                    print("🔍 [finishScroll] Triggering swipe LEFT")
                    DispatchQueue.main.async { self.onSwipeLeft() }
                } else {
                    print("🔍 [finishScroll] Triggering swipe RIGHT")
                    DispatchQueue.main.async { self.onSwipeRight() }
                }
            } else {
                print("🔍 [finishScroll] Scroll too small, no gesture triggered")
            }

            cumulativeScrollX = 0
            cumulativeScrollY = 0
        }
    }
}

extension View {
    func onTrackpadSwipe(
        onSwipeUp: @escaping () -> Void = {},
        onSwipeDown: @escaping () -> Void = {},
        onSwipeLeft: @escaping () -> Void = {},
        onSwipeRight: @escaping () -> Void = {}
    ) -> some View {
        modifier(TrackpadGestureModifier(
            onSwipeUp: onSwipeUp,
            onSwipeDown: onSwipeDown,
            onSwipeLeft: onSwipeLeft,
            onSwipeRight: onSwipeRight
        ))
    }
}
