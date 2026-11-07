import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// The latest screenshots from ~/Pictures/Screenshots. Click opens one, the pencil edits it in the screenshot editor.
Column {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    property var files: []
    spacing: 8

    function refresh(): void { if (!lister.running) lister.running = true }
    onVisibleChanged: if (visible) root.refresh()
    Component.onCompleted: root.refresh()

    Process {
        id: lister
        command: ["sh", "-c", "ls -t \"$1\"/*.png 2>/dev/null | head -6", "sh", root.dir]
        stdout: StdioCollector { onStreamFinished: root.files = text.split("\n").filter(l => l.length > 0) }
    }

    BarText { visible: root.files.length === 0; text: "No screenshots yet"; color: BarStyle.subtext; font.pixelSize: 12 }

    Grid {
        columns: 3
        spacing: 8
        Repeater {
            model: root.files
            delegate: ClippingRectangle {
                id: cell
                required property string modelData
                width: Math.floor((root.width - 16) / 3); height: Math.round(width * 0.64)
                radius: 12
                color: BarStyle.cardHigh
                Image {
                    anchors.fill: parent
                    source: "file://" + cell.modelData
                    sourceSize.width: 240
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                Rectangle { anchors.fill: parent; color: "black"; opacity: cellHover.hovered ? 0.25 : 0; Behavior on opacity { NumberAnimation { duration: 100 } } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["xdg-open", cell.modelData]) }
                Rectangle {
                    visible: cellHover.hovered || editArea.containsMouse
                    x: parent.width - width - 6; y: 6
                    width: 26; height: 26; radius: 13
                    color: editArea.containsMouse ? BarStyle.accent : BarStyle.surface
                    BarIcon { anchors.centerIn: parent; name: "draw"; size: 15; color: editArea.containsMouse ? BarStyle.onAccent : BarStyle.text }
                    MouseArea { id: editArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "screenshot", "edit", cell.modelData]) }
                }
                HoverHandler { id: cellHover }
            }
        }
    }
}
