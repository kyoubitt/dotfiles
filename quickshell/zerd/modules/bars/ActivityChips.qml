import QtQuick

// What is recording, sharing or listening, as small chips.
Flow {
    id: root

    spacing: 6
    visible: BarActivity.any
    Repeater {
        model: BarActivity.chips
        delegate: Rectangle {
            required property var modelData
            height: 26; width: chipRow.implicitWidth + 18; radius: 13
            color: modelData.hot ? Qt.rgba(1, 0.41, 0.38, 0.18) : BarStyle.plateHover
            border.width: 1
            border.color: modelData.hot ? Qt.rgba(1, 0.41, 0.38, 0.5) : BarStyle.border
            Row {
                id: chipRow; anchors.centerIn: parent; spacing: 5
                BarIcon { name: modelData.icon; size: 14; fill: 1; color: modelData.hot ? BarStyle.danger : BarStyle.subtext }
                BarText { text: modelData.text + (modelData.sub.length > 0 ? "  ·  " + modelData.sub : ""); font.pixelSize: 11 }
            }
        }
    }
}
