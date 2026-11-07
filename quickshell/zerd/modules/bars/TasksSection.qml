import QtQuick
import qs.services

// The to-do list: tick, delete, and add one at the bottom.
Column {
    id: root

    spacing: 4
    readonly property var items: { Todo.list; return Todo.list }

    BarText { visible: root.items.length === 0; text: "Nothing to do"; color: BarStyle.subtext; font.pixelSize: 12 }
    Repeater {
        model: root.items
        delegate: Item {
            required property var modelData
            required property int index
            width: root.width; height: 30
            Rectangle {
                id: box
                x: 2; anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18; radius: 9
                color: modelData.done ? BarStyle.accent : "transparent"
                border.width: 1.5; border.color: modelData.done ? BarStyle.accent : BarStyle.subtext
                BarIcon { anchors.centerIn: parent; visible: modelData.done; name: "check"; size: 12; color: BarStyle.onAccent }
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: modelData.done ? Todo.markUnfinished(index) : Todo.markDone(index) }
            }
            BarText { x: 30; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 30 - 26; text: modelData.content; elide: Text.ElideRight; color: modelData.done ? BarStyle.subtext : BarStyle.text; font.strikeout: modelData.done }
            BarIcon { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; name: "close"; size: 14; color: BarStyle.subtext
                MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: Todo.deleteItem(index) } }
        }
    }
    Rectangle {
        width: root.width; height: 32; radius: 16
        color: BarStyle.cardHigh
        border.width: 1; border.color: addInput.activeFocus ? BarStyle.accent : BarStyle.border
        BarText { x: 14; anchors.verticalCenter: parent.verticalCenter; visible: addInput.text.length === 0; text: "Add a task"; color: BarStyle.subtext; font.pixelSize: 12 }
        TextInput {
            id: addInput
            x: 14; width: parent.width - 28; height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            color: BarStyle.text; font.pixelSize: 12; clip: true
            onAccepted: { if (text.trim().length > 0) Todo.addTask(text.trim()); text = "" }
        }
    }
}
