import Defaults
import SwiftUI

/// Cached settings for WindowPreview to avoid repeated UserDefaults reads during render.
/// This struct is created once when the preview window is shown and passed to all WindowPreview instances.
struct WindowPreviewSettingsCache {
    // Visual settings
    let windowSwitcherControlPosition: WindowSwitcherControlPosition
    let dockPreviewControlPosition: WindowSwitcherControlPosition
    let selectionOpacity: Double
    let unselectedContentOpacity: Double
    let hoverHighlightColor: Color?
    let allowDynamicImageSizing: Bool
    let useEmbeddedDockPreviewElements: Bool
    let useEmbeddedWindowSwitcherElements: Bool
    let hidePreviewCardBackground: Bool
    let showMinimizedHiddenLabels: Bool
    let useLiquidGlass: Bool
    let previewCardGlassVariant: Int
    let previewCardOpacity: Double
    let previewCardBorderOpacity: Double
    let showPreviewCardBorder: Bool

    // Dock embedded mode settings
    let dockShowWindowTitle: Bool
    let dockWindowTitleVisibility: WindowTitleVisibility
    let dockTrafficLightButtonsVisibility: TrafficLightButtonsVisibility
    let dockEnabledTrafficLightButtons: Set<WindowAction>
    let dockUseMonochromeTrafficLights: Bool
    let dockDisableDockStyleTrafficLights: Bool
    let dockDisableDockStyleTitles: Bool
    let dockDisableButtonHoverEffects: Bool
    let dockShowTrafficLightTooltips: Bool

    // Window Switcher header settings
    let switcherShowHeaderAppIcon: Bool
    let switcherShowHeaderAppName: Bool
    let switcherShowHeaderWindowTitle: Bool
    let switcherHeaderAppIconVisibility: WindowTitleVisibility
    let switcherHeaderAppNameVisibility: WindowTitleVisibility
    let switcherHeaderTitleVisibility: WindowTitleVisibility

    // Window Switcher embedded mode settings
    let switcherShowWindowTitle: Bool
    let switcherWindowTitleVisibility: WindowTitleVisibility
    let switcherTrafficLightButtonsVisibility: TrafficLightButtonsVisibility
    let switcherEnabledTrafficLightButtons: Set<WindowAction>
    let switcherUseMonochromeTrafficLights: Bool
    let switcherDisableDockStyleTrafficLights: Bool
    let switcherDisableDockStyleTitles: Bool
    let switcherDisableButtonHoverEffects: Bool
    let switcherShowTrafficLightTooltips: Bool

    // Behavior settings
    let tapEquivalentInterval: Double
    let previewHoverAction: PreviewHoverAction
    let showActiveWindowBorder: Bool
    let activeAppIndicatorColor: Color
    let enableLivePreview: Bool
    let enableLivePreviewForDock: Bool
    let enableLivePreviewForWindowSwitcher: Bool
    let dockLivePreviewQuality: LivePreviewQuality
    let dockLivePreviewFrameRate: LivePreviewFrameRate
    let windowSwitcherLivePreviewQuality: LivePreviewQuality
    let windowSwitcherLivePreviewFrameRate: LivePreviewFrameRate
    let showAnimations: Bool

    /// Creates a cached snapshot of all WindowPreview-related settings from UserDefaults.
    /// Call this once when showing the preview window, not during each render.
    @MainActor
    static func current() -> WindowPreviewSettingsCache {
        WindowPreviewSettingsCache(
            windowSwitcherControlPosition: Defaults[.windowSwitcherControlPosition],
            dockPreviewControlPosition: Defaults[.dockPreviewControlPosition],
            selectionOpacity: Defaults[.selectionOpacity],
            unselectedContentOpacity: Defaults[.unselectedContentOpacity],
            hoverHighlightColor: Defaults[.hoverHighlightColor],
            allowDynamicImageSizing: Defaults[.allowDynamicImageSizing],
            useEmbeddedDockPreviewElements: Defaults[.useEmbeddedDockPreviewElements],
            useEmbeddedWindowSwitcherElements: Defaults[.useEmbeddedWindowSwitcherElements],
            hidePreviewCardBackground: Defaults[.hidePreviewCardBackground],
            showMinimizedHiddenLabels: Defaults[.showMinimizedHiddenLabels],
            useLiquidGlass: Defaults[.useLiquidGlass],
            previewCardGlassVariant: Defaults[.previewCardGlassVariant],
            previewCardOpacity: Defaults[.previewCardOpacity],
            previewCardBorderOpacity: Defaults[.previewCardBorderOpacity],
            showPreviewCardBorder: Defaults[.showPreviewCardBorder],
            dockShowWindowTitle: Defaults[.dockShowWindowTitle],
            dockWindowTitleVisibility: Defaults[.dockWindowTitleVisibility],
            dockTrafficLightButtonsVisibility: Defaults[.dockTrafficLightButtonsVisibility],
            dockEnabledTrafficLightButtons: Defaults[.dockEnabledTrafficLightButtons],
            dockUseMonochromeTrafficLights: Defaults[.dockUseMonochromeTrafficLights],
            dockDisableDockStyleTrafficLights: Defaults[.dockDisableDockStyleTrafficLights],
            dockDisableDockStyleTitles: Defaults[.dockDisableDockStyleTitles],
            dockDisableButtonHoverEffects: Defaults[.dockDisableButtonHoverEffects],
            dockShowTrafficLightTooltips: Defaults[.dockShowTrafficLightTooltips],
            switcherShowHeaderAppIcon: Defaults[.switcherShowHeaderAppIcon],
            switcherShowHeaderAppName: Defaults[.switcherShowHeaderAppName],
            switcherShowHeaderWindowTitle: Defaults[.switcherShowHeaderWindowTitle],
            switcherHeaderAppIconVisibility: Defaults[.switcherHeaderAppIconVisibility],
            switcherHeaderAppNameVisibility: Defaults[.switcherHeaderAppNameVisibility],
            switcherHeaderTitleVisibility: Defaults[.switcherHeaderTitleVisibility],
            switcherShowWindowTitle: Defaults[.switcherShowWindowTitle],
            switcherWindowTitleVisibility: Defaults[.switcherWindowTitleVisibility],
            switcherTrafficLightButtonsVisibility: Defaults[.switcherTrafficLightButtonsVisibility],
            switcherEnabledTrafficLightButtons: Defaults[.switcherEnabledTrafficLightButtons],
            switcherUseMonochromeTrafficLights: Defaults[.switcherUseMonochromeTrafficLights],
            switcherDisableDockStyleTrafficLights: Defaults[.switcherDisableDockStyleTrafficLights],
            switcherDisableDockStyleTitles: Defaults[.switcherDisableDockStyleTitles],
            switcherDisableButtonHoverEffects: Defaults[.switcherDisableButtonHoverEffects],
            switcherShowTrafficLightTooltips: Defaults[.switcherShowTrafficLightTooltips],
            tapEquivalentInterval: Defaults[.tapEquivalentInterval],
            previewHoverAction: Defaults[.previewHoverAction],
            showActiveWindowBorder: Defaults[.showActiveWindowBorder],
            activeAppIndicatorColor: Defaults[.activeAppIndicatorColor],
            enableLivePreview: Defaults[.enableLivePreview],
            enableLivePreviewForDock: Defaults[.enableLivePreviewForDock],
            enableLivePreviewForWindowSwitcher: Defaults[.enableLivePreviewForWindowSwitcher],
            dockLivePreviewQuality: Defaults[.dockLivePreviewQuality],
            dockLivePreviewFrameRate: Defaults[.dockLivePreviewFrameRate],
            windowSwitcherLivePreviewQuality: Defaults[.windowSwitcherLivePreviewQuality],
            windowSwitcherLivePreviewFrameRate: Defaults[.windowSwitcherLivePreviewFrameRate],
            showAnimations: Defaults[.showAnimations]
        )
    }
}

/// Cached settings for WindowPreviewHoverContainer to avoid repeated UserDefaults reads.
struct HoverContainerSettingsCache {
    let uniformCardRadius: Bool
    let showAppTitleData: Bool
    let appNameStyle: AppNameStyle
    let dockShowHeaderAppIcon: Bool
    let dockShowHeaderAppName: Bool
    let aeroShakeAction: AeroShakeAction
    let previewMaxColumns: Int
    let previewMaxRows: Int
    let switcherMaxRows: Int
    let switcherMaxColumns: Int
    let previewWindowSpacing: CGFloat
    let gradientColorPalette: GradientColorPaletteSettings
    let showAnimations: Bool
    let enableMouseHoverInSwitcher: Bool
    let enableEdgeScrollInSwitcher: Bool
    let edgeScrollSpeed: Double
    let dynamicEdgeScrollSpeed: Bool
    let windowSwitcherLivePreviewScope: WindowSwitcherLivePreviewScope
    let windowSwitcherCompactThreshold: Int
    let dockPreviewCompactThreshold: Int
    let cmdTabCompactThreshold: Int
    let disableImagePreview: Bool

    @MainActor
    static func current() -> HoverContainerSettingsCache {
        HoverContainerSettingsCache(
            uniformCardRadius: Defaults[.uniformCardRadius],
            showAppTitleData: Defaults[.showAppName],
            appNameStyle: Defaults[.appNameStyle],
            dockShowHeaderAppIcon: Defaults[.dockShowHeaderAppIcon],
            dockShowHeaderAppName: Defaults[.dockShowHeaderAppName],
            aeroShakeAction: Defaults[.aeroShakeAction],
            previewMaxColumns: Defaults[.previewMaxColumns],
            previewMaxRows: Defaults[.previewMaxRows],
            switcherMaxRows: Defaults[.switcherMaxRows],
            switcherMaxColumns: Defaults[.switcherMaxColumns],
            previewWindowSpacing: Defaults[.previewWindowSpacing],
            gradientColorPalette: Defaults[.gradientColorPalette],
            showAnimations: Defaults[.showAnimations],
            enableMouseHoverInSwitcher: Defaults[.enableMouseHoverInSwitcher],
            enableEdgeScrollInSwitcher: Defaults[.enableEdgeScrollInSwitcher],
            edgeScrollSpeed: Defaults[.edgeScrollSpeed],
            dynamicEdgeScrollSpeed: Defaults[.dynamicEdgeScrollSpeed],
            windowSwitcherLivePreviewScope: Defaults[.windowSwitcherLivePreviewScope],
            windowSwitcherCompactThreshold: Defaults[.windowSwitcherCompactThreshold],
            dockPreviewCompactThreshold: Defaults[.dockPreviewCompactThreshold],
            cmdTabCompactThreshold: Defaults[.cmdTabCompactThreshold],
            disableImagePreview: Defaults[.disableImagePreview]
        )
    }
}
