import QtQuick
import Quickshell.Widgets
import qs.modules.bars

// Back and forward over where you have been, the search box, and you.
Item {
    id: root
    height: 68

    component Round: Rectangle {
        id: rb
        property string icon
        property bool enabled_: true
        signal tapped()
        width: 40; height: 40; radius: 20
        color: hv.hovered && enabled_ ? BarStyle.plateHover : BarStyle.plate
        opacity: enabled_ ? 1 : 0.35
        Behavior on color { ColorAnimation { duration: 90 } }
        scale: tp.pressed ? 0.92 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.45 } }
        BarIcon { anchors.centerIn: parent; name: rb.icon; size: 22; color: BarStyle.text }
        HoverHandler { id: hv }
        TapHandler { id: tp; onTapped: if (rb.enabled_) rb.tapped() }
    }

    Row { x: 26; anchors.verticalCenter: parent.verticalCenter; spacing: 8
        Round { icon: "chevron_left"; enabled_: MusicStore.canBack; onTapped: MusicStore.back() }
        Round { icon: "chevron_right"; enabled_: MusicStore.canForward; onTapped: MusicStore.forward() }
    }
    Rectangle {
        anchors.centerIn: parent; width: Math.min(480, parent.width - 260); height: 44; radius: 22
        color: BarStyle.plate; border.width: 1; border.color: box.activeFocus ? MusicStore.accent : BarStyle.border
        Behavior on border.color { ColorAnimation { duration: 100 } }
        BarIcon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 22; color: BarStyle.subtext }
        TextInput {
            id: box
            x: 50; width: parent.width - 90; anchors.verticalCenter: parent.verticalCenter
            color: BarStyle.text; font.pixelSize: 15; clip: true; selectByMouse: true
            text: MusicStore.query
            onTextChanged: { MusicStore.query = text; if (text.length > 0 && MusicStore.page !== "search") MusicStore.go("search", null) }
            onActiveFocusChanged: if (activeFocus && MusicStore.page !== "search") MusicStore.go("search", null)
            Keys.onEscapePressed: { text = ""; focus = false }
        }
        EText { x: 50; anchors.verticalCenter: parent.verticalCenter; visible: box.text.length === 0; text: "What do you want to play?"; color: BarStyle.subtext }
        Rectangle { visible: box.text.length > 0; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } width: 26; height: 26; radius: 13; color: xHov.hovered ? BarStyle.border : "transparent"
            BarIcon { anchors.centerIn: parent; name: "close"; size: 16; color: BarStyle.subtext }
            HoverHandler { id: xHov }
            TapHandler { onTapped: box.text = "" } }
    }
    Item {
        anchors { right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter } width: 44; height: 44
        scale: avTap.pressed ? 0.92 : (avHov.hovered ? 1.06 : 1)
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.45 } }
        ClippingRectangle {
            anchors.fill: parent; radius: 22; color: MusicStore.accent
            Image { anchors.fill: parent; source: CoverCache.src((MusicStore.me?.images ?? [])[0]?.url ?? ""); sourceSize: Qt.size(96, 96); fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; visible: status === Image.Ready }
            EText { anchors.centerIn: parent; visible: !(MusicStore.me?.images ?? []).length; text: (MusicStore.name || "?").charAt(0).toUpperCase(); font.weight: Font.Bold; color: MusicStore.onAccent }
        }
        HoverHandler { id: avHov }
        TapHandler { id: avTap; onTapped: MusicStore.go("profile", null) }
    }
}
