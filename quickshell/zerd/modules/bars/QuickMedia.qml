import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.services

// The player on a blurred copy of its own cover.
ClippingRectangle {
    id: root

    implicitHeight: media.implicitHeight + 28
    radius: 22
    color: BarStyle.plateHover

    Image {
        id: art
        anchors.fill: parent
        source: NowPlaying.player?.trackArtUrl ?? ""
        sourceSize: Qt.size(Math.max(1, Math.round(width * 2)), Math.max(1, Math.round(height * 2)))
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: parent
        source: art
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: -0.35
        opacity: art.status === Image.Ready ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }
    MediaPopup { id: media; x: 14; y: 14; width: root.width - 28 }
}
