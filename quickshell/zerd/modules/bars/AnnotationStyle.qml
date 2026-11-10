import QtQuick

// Colour, size and fill for an AnnotationLayer.
Row {
    id: root

    required property var ann
    spacing: 10

    Repeater {
        model: [BarStyle.accent, "#ff5d5d", "#ffd166", "#06d6a0", "#4cc9f0", "#ffffff", "#000000"]
        delegate: Rectangle {
            required property var modelData
            readonly property bool picked: String(root.ann.ink) === String(Qt.color(modelData))
            width: 26; height: 26; radius: 17
            anchors.verticalCenter: parent.verticalCenter
            color: modelData
            border.width: picked ? 3 : 1
            border.color: picked ? BarStyle.text : BarStyle.border
            scale: swArea.containsMouse ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
            MouseArea { id: swArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.ann.ink = parent.modelData }
        }
    }
    Item { width: 9; height: 36; Rectangle { anchors.centerIn: parent; width: 1; height: 24; color: BarStyle.border } }
    Repeater {
        model: [{ l: "S", v: 3 }, { l: "M", v: 6 }, { l: "L", v: 12 }]
        delegate: Rectangle {
            required property var modelData
            readonly property bool picked: root.ann.inkSize === modelData.v
            width: 40; height: 32; radius: 10
            anchors.verticalCenter: parent.verticalCenter
            color: picked ? BarStyle.text : (szArea.containsMouse ? BarStyle.plateHover : "transparent")
            border.width: picked ? 0 : 1; border.color: BarStyle.border
            BarText { anchors.centerIn: parent; text: parent.modelData.l; font.weight: Font.DemiBold; color: parent.picked ? BarStyle.surface : BarStyle.text }
            MouseArea { id: szArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.ann.inkSize = parent.modelData.v }
        }
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        ShotButton { icon: "remove"; tip: "Thinner"; onTapped: root.ann.inkSize = Math.max(1, root.ann.inkSize - 1) }
        BarText { anchors.verticalCenter: parent.verticalCenter; width: 28; horizontalAlignment: Text.AlignHCenter; text: String(root.ann.inkSize) }
        ShotButton { icon: "add"; tip: "Thicker"; onTapped: root.ann.inkSize = Math.min(40, root.ann.inkSize + 1) }
    }
    ShotButton { icon: "format_color_fill"; tip: "Fill shapes"; on: root.ann.fill; onTapped: root.ann.fill = !root.ann.fill }
}
