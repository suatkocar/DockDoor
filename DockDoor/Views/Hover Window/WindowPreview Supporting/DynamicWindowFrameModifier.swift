import SwiftUI

// Import WindowImageSizingCalculations for dimension calculations
// WindowImageSizingCalculations is defined in Window Image Sizing Calculations.swift

struct DynamicWindowFrameModifier: ViewModifier {
    let allowDynamicSizing: Bool
    let dimensions: WindowImageSizingCalculations.WindowDimensions
    let dockPosition: DockPosition
    let windowSwitcherActive: Bool

    func body(content: Content) -> some View {
        if allowDynamicSizing {
            // Dynamic sizing: use calculated dimensions with scaledToFit for natural scaling
            let isHorizontalFlow = dockPosition.isHorizontalFlow || windowSwitcherActive

            if isHorizontalFlow {
                // Horizontal flow: use exact calculated dimensions for both width and height
                content
                    .frame(width: dimensions.size.width > 0 ? dimensions.size.width : nil,
                           height: dimensions.size.height > 0 ? dimensions.size.height : nil)
                    .clipped()
                    .frame(maxWidth: dimensions.maxDimensions.width,
                           maxHeight: dimensions.maxDimensions.height)
            } else {
                // Vertical flow: use exact calculated dimensions for both width and height
                content
                    .frame(width: dimensions.size.width > 0 ? dimensions.size.width : nil,
                           height: dimensions.size.height > 0 ? dimensions.size.height : nil)
                    .clipped()
                    .frame(maxWidth: dimensions.maxDimensions.width,
                           maxHeight: dimensions.maxDimensions.height)
            }
        } else {
            // Fixed sizing: use the computed dimensions exactly
            content
                .frame(width: max(dimensions.size.width, 50),
                       height: dimensions.size.height,
                       alignment: .center)
                .frame(maxWidth: dimensions.maxDimensions.width,
                       maxHeight: dimensions.maxDimensions.height)
        }
    }
}

extension View {
    func dynamicWindowFrame(
        allowDynamicSizing: Bool,
        dimensions: WindowImageSizingCalculations.WindowDimensions,
        dockPosition: DockPosition,
        windowSwitcherActive: Bool
    ) -> some View {
        modifier(DynamicWindowFrameModifier(
            allowDynamicSizing: allowDynamicSizing,
            dimensions: dimensions,
            dockPosition: dockPosition,
            windowSwitcherActive: windowSwitcherActive
        ))
    }
}
