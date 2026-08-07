pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: panelRoot
        required property var modelData

        // Intentionally not the shared waffles.background.backdrop settings -
        // that dim (80%) is tuned for opaque modal/dialog scrims, not for a
        // wallpaper that should still read through the overview.
        readonly property real overviewDim: 0.3
        readonly property real overviewBlur: 0.35
        readonly property real overviewBlurMax: 56
        readonly property var wBackdrop: Config.options.waffles?.background?.backdrop ?? {}
        readonly property string wallpaperUrl: {
            const path = Config.options.background.wallpaperPath;
            if (!path) return "";
            return path.startsWith("file://") ? path : "file://" + path;
        }

        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:wOverviewBackdrop"
        anchors { top: true; bottom: true; left: true; right: true }

        visible: (wBackdrop.enable ?? true) && NiriService.inOverview
        color: "transparent"

        // Static blur of the wallpaper image itself (GPU layer effect, computed
        // once and cached - not a live capture) so the overview never picks up
        // other on-screen content like widgets or media art.
        Image {
            id: blurredWallpaper
            anchors.fill: parent
            source: panelRoot.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
            sourceSize.width: width
            sourceSize.height: height
            visible: panelRoot.visible

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                source: blurredWallpaper
                anchors.fill: blurredWallpaper
                blurEnabled: Appearance.effectsEnabled
                blur: panelRoot.overviewBlur
                blurMax: panelRoot.overviewBlurMax
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, panelRoot.overviewDim)
        }
    }
}
