import Defaults
import SwiftUI

struct DockStyleModifier: ViewModifier {
    @Default(.useLiquidGlass) private var useLiquidGlass
    let cornerRadius: Double
    let highlightColor: Color?
    let backgroundOpacity: CGFloat
    let frostedTranslucentLayer: Bool
    let variant: Int?

    @Default(.containerGlassVariant) private var containerGlassVariant
    @Default(.containerBorderOpacity) private var containerBorderOpacity
    @Default(.showContainerBorder) private var showContainerBorder

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), useLiquidGlass {
            content
                .background {
                    BlurView(variant: variant ?? containerGlassVariant, frostedTranslucentLayer: frostedTranslucentLayer)
                        .opacity(backgroundOpacity)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .overlay {
                            if showContainerBorder {
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke(Color.white.opacity(0.2 * containerBorderOpacity), lineWidth: 1)
                                    .blur(radius: 1.5)
                                    .blendMode(.plusLighter)
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3 * containerBorderOpacity),
                                                Color.white.opacity(0.05 * containerBorderOpacity),
                                                Color.white.opacity(0.1 * containerBorderOpacity),
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.5
                                    )
                            }
                        }
                        .allowsHitTesting(false)
                }
                .padding(2)
        } else {
            content
                .background {
                    ZStack {
                        BlurView(variant: variant, frostedTranslucentLayer: frostedTranslucentLayer)
                            .opacity(backgroundOpacity)
                        if let hc = highlightColor {
                            FluidGradient(blobs: hc.generateShades(count: 3), highlights: hc.generateShades(count: 3), speed: 0.5, blur: 0.75)
                                .opacity(0.2 * backgroundOpacity)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .borderedBackground(.primary.opacity(0.19 * backgroundOpacity), lineWidth: 1.5, shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                }
                .padding(2)
        }
    }
}

extension View {
    func dockStyle(cornerRadius: Double = Defaults[.uniformCardRadius] ? 26 : 8, highlightColor: Color? = nil, backgroundOpacity: CGFloat = 1.0, frostedTranslucentLayer: Bool = false, variant: Int? = nil) -> some View {
        modifier(DockStyleModifier(cornerRadius: cornerRadius, highlightColor: highlightColor, backgroundOpacity: backgroundOpacity, frostedTranslucentLayer: frostedTranslucentLayer, variant: variant))
    }

    func simpleBlurBackground(variant: Int = 18, cornerRadius: Double = Defaults[.uniformCardRadius] ? 20 : 0, strokeOpacity: Double = 0.1, strokeWidth: Double = 1.5) -> some View {
        background {
            BlurView(variant: variant)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .borderedBackground(.secondary.opacity(0.19), lineWidth: strokeWidth, shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
