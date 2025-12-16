import Defaults
import SwiftUI

struct BlurView: View {
    @Default(.useLiquidGlass) private var useLiquidGlass
    @Default(.containerGlassVariant) private var containerGlassVariant
    let variant: Int?
    let frostedTranslucentLayer: Bool

    init(variant: Int? = nil, frostedTranslucentLayer: Bool = false) {
        self.variant = variant
        self.frostedTranslucentLayer = frostedTranslucentLayer
    }

    var body: some View {
        if #available(macOS 26.0, *), useLiquidGlass {
            GlassEffectView(variant: variant ?? containerGlassVariant, opacity: 1.0, frostedTranslucentLayer: frostedTranslucentLayer)
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}

@available(macOS 26.0, *)
struct GlassEffectView: NSViewRepresentable {
    let variant: Int
    let opacity: CGFloat
    let frostedTranslucentLayer: Bool

    init(variant: Int = 19, opacity: CGFloat = 1.0, frostedTranslucentLayer: Bool = false) {
        // Clamp variant to valid range 0-19
        self.variant = max(0, min(19, variant))
        self.opacity = opacity
        self.frostedTranslucentLayer = frostedTranslucentLayer
    }

    func makeNSView(context: Context) -> NSView {
        let glassView = NSGlassEffectView()
        setGlassVariant(glassView, variant: variant)
        glassView.alphaValue = opacity
        return glassView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let glassView = nsView as? NSGlassEffectView {
            setGlassVariant(glassView, variant: variant)
            glassView.alphaValue = opacity
        }
    }

    private func setGlassVariant(_ glassView: NSGlassEffectView, variant: Int) {
        glassView.setValue(NSNumber(value: variant), forKey: "_variant")
    }
}

struct MaterialBlurView: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}
