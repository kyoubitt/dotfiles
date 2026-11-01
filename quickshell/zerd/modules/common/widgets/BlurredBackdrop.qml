import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.common
import qs.services

// A cropped, blurred copy of the current wallpaper, positioned to align
// with whatever's actually behind this item on screen - genuine background
// blur for floating panels (notification cards, toasts, the clipboard/
// notification center flyouts), not just a tinted-alpha fill on its own.
//
// Unlike GlassBackground (modules/common/widgets/GlassBackground.qml),
// this never gates on the aurora/inir theme toggles - those panels want
// the glass look unconditionally, not just under one specific theme mode.
// It also doesn't attempt per-item precision via mapToItem - the caller
// passes the *window's* resolved screen position once, which every item in
// that window shares. For a continuous wallpaper that's visually
// indistinguishable from pixel-perfect per-item alignment, and avoids
// re-deriving position for every card in a list separately.
Item {
    id: root

    required property real screenX
    required property real screenY
    property real screenWidth: Quickshell.screens[0]?.width ?? 1920
    property real screenHeight: Quickshell.screens[0]?.height ?? 1080

    clip: true

    Image {
        id: blurredWallpaper
        x: -root.screenX
        y: -root.screenY
        width: root.screenWidth
        height: root.screenHeight
        source: Wallpapers.effectiveWallpaperUrl
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        sourceSize.width: width
        sourceSize.height: height

        layer.enabled: Appearance.effectsEnabled
        // Softer than the shared StyledBlurEffect (blur 1 / blurMax 100),
        // which smears the wallpaper into a flat colour wash on a small
        // pill - this keeps some of the wallpaper's shape visible.
        layer.effect: MultiEffect {
            source: blurredWallpaper
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 32
            blur: 0.45
            saturation: 0.1
        }
    }
}
