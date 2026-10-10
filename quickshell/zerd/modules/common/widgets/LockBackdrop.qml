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
        sourceSize.width: width
        sourceSize.height: height
        asynchronous: true
        cache: true

        layer.enabled: Appearance.effectsEnabled
        layer.effect: MultiEffect {
            source: bgSource
            anchors.fill: bgSource
            blurEnabled: true
            blur: 1.0
            blurMax: 64
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim
    }
}
