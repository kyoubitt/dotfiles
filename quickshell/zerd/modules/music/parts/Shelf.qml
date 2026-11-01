import QtQuick
import qs.modules.bars
import qs.modules.music

// A titled row of cards that rises in when it appears.
Item {
    id: root
    property string title: ""
    property var model: []
    property string kind: "playlist"
    property int artSize: 150
    property int order: 0
    width: parent ? parent.width : 600
    height: visible ? 52 + artSize + 66 : 0
    visible: (model?.length ?? 0) > 0
    opacity: 0
    property real lift: 20
    Component.onCompleted: rise.start()
    SequentialAnimation {
        id: rise
        PauseAnimation { duration: root.order * 70 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "lift"; to: 0; duration: 260; easing.type: Easing.OutCubic }
        }
    }
    EText { y: 6 + root.lift; text: root.title; font.pixelSize: 21; font.weight: Font.DemiBold }
    ListView {
        y: 46 + root.lift; width: parent.width; height: root.artSize + 66
        orientation: ListView.Horizontal; spacing: 6; clip: true; boundsBehavior: Flickable.StopAtBounds
        model: root.model
        delegate: Card { required property var modelData; item: modelData; kind: root.kind; artSize: root.artSize }
    }
}
