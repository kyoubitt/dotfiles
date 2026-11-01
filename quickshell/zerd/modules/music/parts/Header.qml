import QtQuick
import Quickshell.Widgets
import qs.modules.bars
import qs.modules.music

// The top of a playlist, album or artist page: a colour wash from the cover, the art, the name, and buttons.
Item {
    id: root
    property string art: ""
    property string kind: "Playlist"
    property string title: ""
    property string subtitle: ""
    property bool round: false
    property string icon: ""
    property alias actions: row.data
    width: parent ? parent.width : 600
    height: Math.max(250, headCol.implicitHeight + 56)

    ClippingRectangle {
        anchors.fill: parent; radius: 30; color: BarStyle.plate
        Image { anchors.fill: parent; source: root.art; sourceSize: Qt.size(16, 16); fillMode: Image.PreserveAspectCrop; smooth: true; cache: false; opacity: 0.55 }
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#22000000" } GradientStop { position: 1; color: "#aa000000" } } }
    }
    ClippingRectangle {
        x: 28; y: 28; width: 194; height: 194; radius: root.round ? 97 : 20; color: root.art.length === 0 ? Qt.rgba(MusicStore.accent.r, MusicStore.accent.g, MusicStore.accent.b, 0.3) : BarStyle.plate
        BarIcon { visible: root.art.length === 0 && root.icon.length > 0; anchors.centerIn: parent; name: root.icon; fill: 1; size: 84; color: MusicStore.accent }
        Image { anchors.fill: parent; source: root.art; sourceSize: Qt.size(400, 400); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; cache: false }
    }
    Column {
        id: headCol
        x: 250; anchors.bottom: parent.bottom; anchors.bottomMargin: 28; width: parent.width - 280; spacing: 6
        EText { text: root.kind; font.pixelSize: 12; font.weight: Font.DemiBold; color: BarStyle.subtext }
        EText { width: parent.width; elide: Text.ElideRight; text: root.title; font.pixelSize: 34; font.weight: Font.Bold }
        EText { width: parent.width; elide: Text.ElideRight; text: root.subtitle; color: BarStyle.subtext }
        // the buttons wrap onto a second line in a narrow window instead of running off the card
        Flow { id: row; width: parent.width; spacing: 10; topPadding: 8 }
    }
}
