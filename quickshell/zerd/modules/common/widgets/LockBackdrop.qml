import qs.services
import qs.modules.common
import QtQuick
import QtQuick.Effects

// Fullscreen blurred-wallpaper backdrop shared by LockScreen and
// SessionScreen. Not GlassBackground: that component crops the wallpaper
// to a small floating panel's screen position and masks rounded corners,
// neither of which a fullscreen surface needs.
Item {
    id: root

    Image {
        id: bgSource
        anchors.fill: parent
        source: Wallpapers.effectiveWallpaperUrl
        fillMode: Image.PreserveAspectCrop
        // Decoded at a quarter of the screen size: the blur hides the detail
        // anyway, and upscaling the small image gives a smooth gradient
        // instead of the blocky banding a heavy blur of the full image shows.
        sourceSize.width: Math.max(1, Math.round(width / 4))
        sourceSize.height: Math.max(1, Math.round(height / 4))
        smooth: true
        mipmap: true
        asynchronous: true
        cache: true

        layer.enabled: Appearance.effectsEnabled
        layer.smooth: true
        layer.effect: MultiEffect {
            source: bgSource
            anchors.fill: bgSource
            blurEnabled: true
            blur: 0.55
            blurMax: 32
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim
    }
}
