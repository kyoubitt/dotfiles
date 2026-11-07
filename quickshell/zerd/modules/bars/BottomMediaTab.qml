import QtQuick

// The player card and the resource rings, as one tab of the bottom group.
Item {
    Column {
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 0; rightMargin: 14; topMargin: 14 }
        spacing: 10
        QuickMedia { width: parent.width }
        QuickRings { width: parent.width }
    }
}
