pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The editor window: a finished picture to mark up, laid out like Satty (tools across the top, colours and
// the place to save along the bottom). Used for window shots and for the recent-shots pencil; region and
// screen shots are edited right on the capture overlay instead. `ipc call screenshot edit <png>`.
Scope {
    id: root

    property bool open: false
    property string source: ""
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string shotsDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    function edit(path: string): void {
        if (path.length === 0) return
        root.source = path
        root.open = true
    }
    function dismiss(): void {
        // A temporary shot goes away with the editor; saved files stay.
        if (root.source.startsWith(root.runtime)) Quickshell.execDetached(["rm", "-f", root.source])
        root.open = false
    }

    LazyLoader {
        active: root.open
        component: FloatingWindow {
            id: win
            title: "zerd-screenshot"
            implicitWidth: 1280
            implicitHeight: 820
            color: Qt.darker(BarStyle.surface, 1.35)
            visible: true
            onVisibleChanged: if (!visible && root.open) root.dismiss()

            property string fname: Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss") + ".png"
            readonly property real iw: base.status === Image.Ready ? base.sourceSize.width : 1
            readonly property real ih: base.status === Image.Ready ? base.sourceSize.height : 1
            readonly property real cw: marks.crop.width > 0 ? marks.crop.width : iw
            readonly property real ch: marks.crop.height > 0 ? marks.crop.height : ih

            // ---- Output
            function stamp(): string { return Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss") }
            function exportTo(path: string, done: var): void {
                marks.cropDraft = null
                content.grabToImage(r => done(r.saveToFile(path)), Qt.size(Math.round(win.cw), Math.round(win.ch)))
            }
            function doCopy(): void {
                const tmp = root.runtime + "/zerd-shot-copy.png"
                win.exportTo(tmp, ok => {
                    if (!ok) return
                    Quickshell.execDetached(["sh", "-c", "wl-copy -t image/png < \"$1\" && notify-send -a Screenshot -i \"$1\" 'Screenshot copied' 'Paste it anywhere'; rm -f \"$1\"", "sh", tmp])
                    root.dismiss()
                })
            }
            function doSave(path: string): void {
                win.exportTo(path, ok => {
                    if (!ok) return
                    Quickshell.execDetached(["notify-send", "-a", "Screenshot", "-i", path, "Screenshot saved", path.replace(Quickshell.env("HOME"), "~")])
                    root.dismiss()
                })
            }
            function saveDefault(): void {
                let n = win.fname.trim().replace(/[\/]/g, "-")
                if (n.length === 0) n = win.stamp()
                win.doSave(root.shotsDir + "/" + (n.toLowerCase().endsWith(".png") ? n : n + ".png"))
            }
            Process {
                id: picker
                stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p.length > 0) win.doSave(p.endsWith(".png") ? p : p + ".png") } }
            }
            function saveAs(): void {
                picker.command = ["zenity", "--file-selection", "--save", "--confirm-overwrite", "--filename=" + root.shotsDir + "/" + win.stamp() + ".png"]
                picker.running = true
            }

            // ---- Keys
            Item {
                id: keys
                anchors.fill: parent
                focus: !marks.typing
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier, shift = event.modifiers & Qt.ShiftModifier
                    if (event.key === Qt.Key_Escape) root.dismiss()
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.doCopy()
                    else if (ctrl && event.key === Qt.Key_Z) marks.undo()
                    else if (ctrl && event.key === Qt.Key_Y) marks.redo()
                    else if (ctrl && shift && event.key === Qt.Key_S) win.saveAs()
                    else if (ctrl && event.key === Qt.Key_S) win.saveDefault()
                    else if (ctrl && event.key === Qt.Key_C) win.doCopy()
                    else if (event.key === Qt.Key_B) marks.tool = "brush"
                    else if (event.key === Qt.Key_I) marks.tool = "line"
                    else if (event.key === Qt.Key_Z) marks.tool = "arrow"
                    else if (event.key === Qt.Key_R) marks.tool = "rect"
                    else if (event.key === Qt.Key_E) marks.tool = "ellipse"
                    else if (event.key === Qt.Key_T) marks.tool = "text"
                    else if (event.key === Qt.Key_M) marks.tool = "marker"
                    else if (event.key === Qt.Key_U) marks.tool = "blur"
                    else if (event.key === Qt.Key_G) marks.tool = "highlight"
                    else if (event.key === Qt.Key_C) marks.tool = "crop"
                    else return
                    event.accepted = true
                }
            }

            // ---- The picture
            Item {
                id: stage
                x: 0; y: topBar.height
                width: parent.width; height: parent.height - topBar.height - bottomBar.height
                clip: true

                Item {
                    id: fitter
                    readonly property real fit: Math.min((stage.width - 40) / win.cw, (stage.height - 40) / win.ch, 1)
                    width: win.cw; height: win.ch
                    scale: fit
                    transformOrigin: Item.TopLeft
                    x: Math.round((stage.width - width * fit) / 2)
                    y: Math.round((stage.height - height * fit) / 2)

                    // Exported as it stands: the cropped area at the original size.
                    Item {
                        id: content
                        anchors.fill: parent
                        clip: true

                        Item {
                            id: world
                            x: -marks.crop.x; y: -marks.crop.y
                            width: win.iw; height: win.ih
                            Image { id: base; anchors.fill: parent; source: root.source.length > 0 ? "file://" + root.source : ""; cache: false; smooth: true }
                            AnnotationLayer {
                                id: marks
                                anchors.fill: parent
                                imageSource: base.source
                                engaged: true
                                viewScale: fitter.fit
                                onTextFinished: keys.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // ---- Top bar: tools and the quick actions
            Rectangle {
                id: topBar
                width: parent.width; height: 46
                color: BarStyle.surface
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    AnnotationTools { ann: marks; withCrop: true }
                    Item { width: 9; height: 36; Rectangle { anchors.centerIn: parent; width: 1; height: 24; color: BarStyle.border } }
                    ShotButton { icon: "content_copy"; tip: "Copy  (Enter)"; onTapped: win.doCopy() }
                    ShotButton { icon: "save"; tip: "Save  (Ctrl+S)"; onTapped: win.saveDefault() }
                    ShotButton { icon: "save_as"; tip: "Save as…  (Ctrl+Shift+S)"; onTapped: win.saveAs() }
                }
                BarText { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: Math.round(win.cw) + "×" + Math.round(win.ch); color: BarStyle.subtext; font.pixelSize: 13 }
            }

            // ---- Bottom bar: style on the left, the place to save on the right
            Rectangle {
                id: bottomBar
                y: parent.height - height
                width: parent.width; height: 60
                color: BarStyle.surface

                Row {
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    AnnotationStyle { ann: marks }
                    Row {
                        visible: marks.tool === "crop"
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        ShotButton { icon: "close"; tip: "Cancel crop"; onTapped: marks.cropDraft = null }
                        ShotButton {
                            icon: "check"; tip: "Apply crop"; enabledBtn: marks.cropDraft !== null && marks.cropDraft.w > 8 && marks.cropDraft.h > 8
                            onTapped: { const d = marks.cropDraft; marks.applyCrop(Qt.rect(Math.round(d.x), Math.round(d.y), Math.round(d.w), Math.round(d.h))) }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right; anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Rectangle {
                        width: 270; height: 40; radius: 20
                        anchors.verticalCenter: parent.verticalCenter
                        color: BarStyle.plateHover
                        border.width: 1; border.color: nameIn.activeFocus ? BarStyle.accent : BarStyle.border
                        BarIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: "folder"; size: 18; color: BarStyle.subtext }
                        TextInput {
                            id: nameIn
                            x: 40; width: parent.width - 52; height: parent.height
                            verticalAlignment: TextInput.AlignVCenter
                            color: BarStyle.text
                            font.pixelSize: 13
                            clip: true
                            selectByMouse: true
                            text: win.fname
                            onTextEdited: win.fname = text
                            onAccepted: win.saveDefault()
                            Keys.onEscapePressed: keys.forceActiveFocus()
                        }
                        BarTip { text: "Saves to " + root.shotsDir.replace(Quickshell.env("HOME"), "~"); external: nameHover.hovered }
                        HoverHandler { id: nameHover }
                    }
                    Rectangle {
                        width: saveRow.implicitWidth + 32; height: 40; radius: 20
                        anchors.verticalCenter: parent.verticalCenter
                        color: saveArea.pressed ? BarStyle.border : BarStyle.accent
                        scale: saveArea.pressed ? 0.97 : 1
                        Behavior on scale { NumberAnimation { duration: 70 } }
                        Row {
                            id: saveRow; anchors.centerIn: parent; spacing: 7
                            BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "save"; size: 19; color: BarStyle.onAccent }
                            BarText { anchors.verticalCenter: parent.verticalCenter; text: "Save"; font.weight: Font.DemiBold; color: BarStyle.onAccent }
                        }
                        MouseArea { id: saveArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.saveDefault() }
                    }
                    Rectangle {
                        width: copyRow.implicitWidth + 32; height: 40; radius: 20
                        anchors.verticalCenter: parent.verticalCenter
                        color: copyArea.pressed ? BarStyle.border : BarStyle.plateHover
                        border.width: 1; border.color: BarStyle.border
                        scale: copyArea.pressed ? 0.97 : 1
                        Behavior on scale { NumberAnimation { duration: 70 } }
                        Row {
                            id: copyRow; anchors.centerIn: parent; spacing: 7
                            BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "content_copy"; size: 19; color: BarStyle.text }
                            BarText { anchors.verticalCenter: parent.verticalCenter; text: "Copy"; font.weight: Font.DemiBold }
                        }
                        MouseArea { id: copyArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.doCopy() }
                    }
                }
            }
        }
    }
}
