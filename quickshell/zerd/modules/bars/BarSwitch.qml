import QtQuick
import "ilya" as Ilya

// Material 3 switch: a track with a thumb. Off is an outlined track with a small thumb; on is the accent with a larger
// thumb and a check. The thumb grows while pressed.
Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 52; implicitHeight: 32
    width: implicitWidth; height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? BarStyle.accent : BarStyle.cardHigh
        border.width: root.checked ? 0 : 2
        border.color: BarStyle.subtext
        Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }
    }
    Rectangle {
        id: thumb
        property real size: ma.pressed ? 28 : (root.checked ? 24 : 16)
        width: size; height: size; radius: size / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - (parent.height - 24) / 2 : 8 + (16 - width) / 2
        color: root.checked ? BarStyle.onAccent : BarStyle.subtext
        Behavior on x { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutCubic } }
        Behavior on size { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }
        BarIcon { anchors.centerIn: parent; visible: root.checked; name: "check"; size: 16; color: BarStyle.accent }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    MouseArea { id: ma; anchors.fill: parent; onClicked: { Ilya.Sounds.playSfx("reusables/toggle/sfx.wav", 0.7); root.toggled() } }
}
