pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common

// Clipboard history inside the quick panel: search, text and images, pinned snippets.
// Click copies; in the search box Enter copies, Shift+Enter pastes into the window you came from,
// Ctrl+P pins, Delete removes, Tab changes the filter. `ipc call clipboard toggle` (Mod+V) opens the
// panel on this section with the search focused.
Column {
    id: root

    readonly property var pinned: Config.options?.bars?.clipboard?.pinned ?? []
    property string query: ""
    property string tab: "all"
    property int sel: 0
    property bool confirmWipe: false
    property string copied: ""
    spacing: 8

    readonly property var rows: {
        const q = root.query.trim().toLowerCase()
        const out = []
        if (root.tab !== "images") {
            for (const p of root.pinned) {
                if (q === "" || p.toLowerCase().includes(q)) out.push({ kind: "pin", text: p })
            }
        }
        for (const e of Cliphist.fuzzyQuery(root.query)) {
            const img = Cliphist.entryIsImage(e)
            if (root.tab === "images" && !img) continue
            if (root.tab === "text" && img) continue
            out.push({ kind: "entry", entry: e, image: img })
        }
        return out
    }
    onRowsChanged: root.sel = Math.min(root.sel, Math.max(0, root.rows.length - 1))

    function pinText(text: string): void {
        const t = text.length > 4000 ? text.slice(0, 4000) : text
        if (t.trim().length === 0 || root.pinned.includes(t)) return
        Config.options.bars.clipboard.pinned = [t].concat(root.pinned)
    }
    function unpinText(text: string): void { Config.options.bars.clipboard.pinned = root.pinned.filter(p => p !== text) }
    function copyRow(i: int, paste: bool, close: bool): void {
        const r = root.rows[i]
        if (!r) return
        if (r.kind === "pin") Quickshell.execDetached(["wl-copy", r.text])
        else Cliphist.copy(r.entry)
        root.copied = r.kind === "pin" || !r.image ? "Copied" : "Image copied"
        forget.restart()
        if (paste) Quickshell.execDetached(["sh", "-c", "sleep 0.25; ydotool key 29:1 47:1 47:0 29:0"])
        if (close || paste) BarState.closeAll()
    }
    function removeRow(i: int): void {
        const r = root.rows[i]
        if (!r) return
        if (r.kind === "pin") root.unpinText(r.text)
        else Cliphist.deleteEntry(r.entry)
    }
    function togglePin(i: int): void {
        const r = root.rows[i]
        if (!r) return
        if (r.kind === "pin") root.unpinText(r.text)
        else if (!r.image && !pinProc.running) {
            pinProc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist decode", "sh", r.entry]
            pinProc.running = true
        }
    }
    function cycleTab(): void { root.tab = root.tab === "all" ? "text" : (root.tab === "text" ? "images" : "all") }

    // Brings the section into view and puts the cursor in the search box (Mod+V).
    function focusSearch(): void {
        let p = root.parent
        while (p && p.contentY === undefined) p = p.parent
        if (p) {
            const y = root.mapToItem(p.contentItem, 0, 0).y
            p.contentY = Math.max(0, Math.min(p.contentHeight - p.height, y - 64))
        }
        input.forceActiveFocus()
    }

    Process {
        id: pinProc
        stdout: StdioCollector { onStreamFinished: root.pinText(text) }
    }
    Timer { id: forget; interval: 1400; onTriggered: root.copied = "" }
    Timer { id: focusLater; interval: 380; onTriggered: root.focusSearch() }
    Connections {
        target: BarState
        function onClipboardRequestChanged(): void { Cliphist.refresh(); focusLater.restart() }
    }
    onVisibleChanged: if (visible) Cliphist.refresh()

    // ---- Search and filters
    Rectangle {
        width: parent.width; height: 36; radius: 18
        color: BarStyle.cardHigh
        border.width: 1; border.color: input.activeFocus ? BarStyle.accent : BarStyle.border
        BarIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 16; color: BarStyle.subtext }
        BarText { x: 36; anchors.verticalCenter: parent.verticalCenter; visible: input.text.length === 0; text: "Search clipboard"; color: BarStyle.subtext; font.pixelSize: 12 }
        TextInput {
            id: input
            x: 36; width: parent.width - 50; height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            color: BarStyle.text
            font.pixelSize: 12
            clip: true
            onTextChanged: { root.query = text; root.sel = 0; list.positionViewAtBeginning() }
            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier
                if (event.key === Qt.Key_Escape) { BarState.closeAll(); event.accepted = true }
                else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J)) { root.sel = Math.min(root.rows.length - 1, root.sel + 1); event.accepted = true }
                else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K)) { root.sel = Math.max(0, root.sel - 1); event.accepted = true }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.copyRow(root.sel, !!(event.modifiers & Qt.ShiftModifier), true); event.accepted = true }
                else if (event.key === Qt.Key_Tab) { root.cycleTab(); event.accepted = true }
                else if (ctrl && event.key === Qt.Key_P) { root.togglePin(root.sel); event.accepted = true }
                else if (event.key === Qt.Key_Delete && (ctrl || input.text.length === 0)) { root.removeRow(root.sel); event.accepted = true }
            }
        }
    }
    Item {
        width: parent.width; height: 28
        Row {
            spacing: 6
            Repeater {
                model: [{ id: "all", label: "All" }, { id: "text", label: "Text" }, { id: "images", label: "Images" }]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: root.tab === modelData.id
                    width: chipLabel.implicitWidth + 22; height: 26; radius: 13
                    color: on ? BarStyle.accent : (chipArea.pressed ? BarStyle.border : BarStyle.cardHigh)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    BarText { id: chipLabel; anchors.centerIn: parent; text: parent.modelData.label; font.pixelSize: 12; color: parent.on ? BarStyle.onAccent : BarStyle.text }
                    MouseArea { id: chipArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = parent.modelData.id }
                }
            }
        }
        BarText {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: root.copied.length > 0 ? root.copied : root.rows.length + (root.rows.length === 1 ? " item" : " items")
            color: root.copied.length > 0 ? BarStyle.accent : BarStyle.subtext; font.pixelSize: 11
        }
    }

    // ---- The list
    ListView {
        id: list
        width: parent.width
        height: Math.min(contentHeight, 340)
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: root.rows
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        currentIndex: root.sel
        highlightFollowsCurrentItem: false

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool picked: root.sel === index && input.activeFocus
            readonly property bool isImage: modelData.kind === "entry" && modelData.image
            readonly property string entryId: modelData.kind === "entry" ? Cliphist.idOf(modelData.entry) : ""
            readonly property string preview: modelData.kind === "pin" ? modelData.text.replace(/\s+/g, " ") : modelData.entry.replace(/^\d+\t/, "").replace(/\s+/g, " ")
            width: list.width
            height: isImage ? 76 : 36
            radius: 12
            color: picked || rowHover.hovered ? BarStyle.cardHigh : "transparent"
            Behavior on color { ColorAnimation { duration: 90 } }
            Component.onCompleted: if (isImage) Cliphist.requestContent(modelData.entry)

            BarIcon {
                x: 10; anchors.verticalCenter: parent.verticalCenter
                name: row.modelData.kind === "pin" ? "push_pin" : (row.isImage ? "image" : "content_paste")
                fill: row.modelData.kind === "pin" ? 1 : 0
                size: 15
                color: row.modelData.kind === "pin" ? BarStyle.accent : BarStyle.subtext
            }
            BarText {
                visible: !row.isImage
                x: 34; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 34 - (rowHover.hovered ? 70 : 8)
                elide: Text.ElideRight
                text: row.preview
                font.pixelSize: 12
            }
            Rectangle {
                visible: row.isImage
                x: 34; y: 6
                width: thumb.implicitHeight > 0 ? Math.min(parent.width - 34 - 78, Math.round((height - 4) * thumb.implicitWidth / thumb.implicitHeight) + 4) : 0
                height: parent.height - 12
                radius: 8; color: BarStyle.border
                Image {
                    id: thumb
                    anchors.fill: parent; anchors.margins: 2
                    source: Cliphist.contentCache[row.entryId] ?? ""
                    sourceSize.height: 160
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }
            HoverHandler { id: rowHover }
            MouseArea {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: parent.right; rightMargin: 72 }
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copyRow(row.index, false, false)
            }
            Row {
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                visible: rowHover.hovered
                spacing: 0
                component Act: Rectangle {
                    id: act
                    property string icon
                    property bool lit: false
                    signal tapped()
                    width: 28; height: 28; radius: 14
                    color: actArea.pressed ? BarStyle.border : "transparent"
                    BarIcon { anchors.centerIn: parent; name: act.icon; size: 16; fill: act.lit ? 1 : 0; color: act.lit ? BarStyle.accent : BarStyle.subtext }
                    MouseArea { id: actArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: act.tapped() }
                }
                Act { visible: !row.isImage; icon: "push_pin"; lit: row.modelData.kind === "pin"; onTapped: root.togglePin(row.index) }
                Act { icon: "delete"; onTapped: root.removeRow(row.index) }
            }
        }
    }

    BarText {
        visible: root.rows.length === 0
        text: root.query.length > 0 ? "No match" : "Nothing copied yet"
        color: BarStyle.subtext; font.pixelSize: 12
    }
    Item {
        visible: root.rows.length > 0
        width: parent.width; height: 24
        BarText { anchors.verticalCenter: parent.verticalCenter; text: "Enter copy  ·  Shift+Enter paste  ·  Ctrl+P pin"; color: BarStyle.subtext; font.pixelSize: 10 }
        Rectangle {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: wipeLabel.implicitWidth + 18; height: 22; radius: 11
            color: root.confirmWipe ? BarStyle.danger : (wipeArea.pressed ? BarStyle.border : BarStyle.cardHigh)
            Behavior on color { ColorAnimation { duration: 100 } }
            BarText { id: wipeLabel; anchors.centerIn: parent; text: root.confirmWipe ? "Really clear?" : "Clear all"; font.pixelSize: 10; color: root.confirmWipe ? "white" : BarStyle.text }
            MouseArea {
                id: wipeArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.confirmWipe) { Cliphist.wipe(); root.confirmWipe = false } else { root.confirmWipe = true; wipeReset.restart() } }
            }
            Timer { id: wipeReset; interval: 2500; onTriggered: root.confirmWipe = false }
        }
    }
}
