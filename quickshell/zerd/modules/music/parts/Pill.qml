import QtQuick
import qs.modules.bars
import qs.modules.music

// A rounded button: filled (accent) or quiet (outlined).
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool filled: true
    signal tapped()
    width: label.implicitWidth + (icon.length > 0 ? 58 : 36); height: 40; radius: 20
    color: filled ? (hov.hovered ? Qt.lighter(MusicStore.accent, 1.1) : MusicStore.accent) : (hov.hovered ? BarStyle.plateHover : "transparent")
    border.width: filled ? 0 : 1; border.color: BarStyle.border
    scale: tp.pressed ? 0.95 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.45 } }
    Behavior on color { ColorAnimation { duration: 90 } }
    Row {
        anchors.centerIn: parent; spacing: 8
        BarIcon { visible: root.icon.length > 0; anchors.verticalCenter: parent.verticalCenter; name: root.icon; fill: 1; size: 20; color: root.filled ? MusicStore.onAccent : BarStyle.text }
        EText { id: label; anchors.verticalCenter: parent.verticalCenter; text: root.text; font.weight: Font.DemiBold; color: root.filled ? MusicStore.onAccent : BarStyle.text }
    }
    HoverHandler { id: hov }
    TapHandler { id: tp; onTapped: root.tapped() }
}
