import QtQuick
import Quickshell
import Quickshell.Io

// One scratch note, saved as you type.
Rectangle {
    id: root

    implicitHeight: 150
    radius: BarStyle.radiusMedium
    color: BarStyle.cardHigh
    border.width: 1
    border.color: edit.activeFocus ? BarStyle.accent : BarStyle.border
    property bool loaded: false

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/zerda-notes.txt"
        onLoaded: { edit.text = file.text(); root.loaded = true }
        onLoadFailed: root.loaded = true
    }
    Timer { id: save; interval: 600; onTriggered: file.setText(edit.text) }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 12
        contentHeight: edit.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        TextEdit {
            id: edit
            width: flick.width
            wrapMode: TextEdit.Wrap
            color: BarStyle.text
            selectionColor: BarStyle.accent
            selectedTextColor: BarStyle.onAccent
            font.pixelSize: 13
            onTextChanged: if (root.loaded) save.restart()
            onCursorRectangleChanged: {
                if (cursorRectangle.y < flick.contentY) flick.contentY = cursorRectangle.y
                else if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height) flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height
            }
        }
    }
    BarText { x: 12; y: 12; visible: edit.text.length === 0 && root.loaded; text: "Write something down..."; color: BarStyle.subtext }
}
