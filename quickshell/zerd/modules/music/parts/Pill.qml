import QtQuick
import qs.modules.bars
import qs.modules.music

// A rounded button: filled (the cover's accent) or quiet (outlined). A filled Play / Pause is the big round one.
BarButton {
    id: root
    property string text: ""
    property string icon: ""
    property bool filled: true
    readonly property bool big: filled && (icon === "play_arrow" || icon === "pause")
    tone: filled ? "filled" : "outlined"
    accentColor: MusicStore.accent
    onAccentColor: MusicStore.onAccent
    width: big ? 56 : label.implicitWidth + (icon.length > 0 ? 58 : 36); height: big ? 56 : 40
    radius: height / 2
    Row {
        anchors.centerIn: parent; spacing: 8
        BarIcon { visible: root.icon.length > 0; anchors.verticalCenter: parent.verticalCenter; name: root.icon; fill: 1; size: root.big ? 30 : 20; color: root.ink }
        EText { id: label; visible: !root.big; anchors.verticalCenter: parent.verticalCenter; text: root.text; font.weight: Font.DemiBold; color: root.ink }
    }
}
