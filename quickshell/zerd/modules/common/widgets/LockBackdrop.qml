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
            blur: 0.85
            blurMax: 40
            brightness: -0.04
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim
    }

    // soft vignette: the corners settle, the middle stays clear (same as the login screen)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.2) }
            GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.26) }
        }
    }

    // night light: from 19:00 to 07:00 a warm, slightly dimmed tint, fading in and out by itself
    property int hourNow: new Date().getHours()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.hourNow = new Date().getHours() }
    readonly property bool night: root.hourNow >= 19 || root.hourNow < 7
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(1.0, 0.52, 0.1, 1)
        opacity: root.night ? 0.14 : 0
        Behavior on opacity { NumberAnimation { duration: 600 } }
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.05, 0.02, 0, 1)
        opacity: root.night ? 0.12 : 0
        Behavior on opacity { NumberAnimation { duration: 600 } }
    }
}
