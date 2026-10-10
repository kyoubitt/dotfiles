pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.startMenu
import qs.modules.waffle.looks

Item {
    id: root

    signal closed()
    function close() { root.closed() }
    function focusSearch() { searchInput.forceActiveFocus() }

    readonly property color cardBg: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.1)
    readonly property color codeBg: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.22)
    readonly property color rowHoverBg: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.2)
    readonly property color textCol: SMColors.fg
    readonly property color dimTextCol: ColorUtils.applyAlpha(SMColors.fg, 0.72)
    readonly property color dangerCol: WallustColors.red
    // Wallust drives accent touches here (same reasoning as the code
    // highlighting) so the type label reads as "synced to the wallpaper,"
    // matching the notification center's own accent choice.
    readonly property color accentCol: WallustColors.cyan

    property string searchText: ""
    readonly property list<string> filteredEntries: Cliphist.fuzzyQuery(root.searchText)

    implicitWidth: 400
    implicitHeight: 500

    Component.onCompleted: Cliphist.refresh()

    // Relative timestamps ("2 minutes ago") don't update just because time
    // passes - nothing they depend on changes. Reading this in the same
    // binding forces a periodic re-evaluation.
    property int _tick: 0
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root._tick++ }

    function formatBytes(n) {
        if (n === undefined || n < 0) return ""
        if (n < 1024) return n + " B"
        if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KiB"
        return (n / (1024 * 1024)).toFixed(1) + " MiB"
    }

    function formatTimeAgo(ms) {
        root._tick // force periodic re-evaluation, see Timer above
        if (!ms) return ""
        const diff = Date.now() - ms
        if (diff < 60000) return "now"
        const mins = Math.floor(diff / 60000)
        if (mins < 60) return mins + (mins === 1 ? " minute ago" : " minutes ago")
        const hours = Math.floor(mins / 60)
        if (hours < 24) return hours + (hours === 1 ? " hour ago" : " hours ago")
        const days = Math.floor(hours / 24)
        return days + (days === 1 ? " day ago" : " days ago")
    }

    // No language info is available from cliphist, so this is a heuristic,
    // not a parser - good enough to tell "pasted snippet" from "pasted
    // sentence" for display purposes.
    function looksLikeCode(text) {
        if (!text) return false
        const t = text.trim()
        if (t.length === 0) return false
        const codeHints = /[{};]|=>|\bfunction\b|\bconst\b|\blet\b|\bimport\b|\bclass\b|\bdef\b|<\/?[a-zA-Z][\w-]*>|^\s*[-*]\s|^#!/m
        const lines = t.split("\n")
        const indentedLines = lines.filter(l => /^\s{2,}\S/.test(l)).length
        return codeHints.test(t) || (lines.length > 2 && indentedLines / lines.length > 0.3)
    }

    function entryKind(id, entry) {
        if (Cliphist.entryIsImage(entry)) return "image"
        const content = Cliphist.contentCache[id]
        const sample = content !== undefined ? content : StringUtils.cleanCliphistEntry(entry)
        return root.looksLikeCode(sample) ? "code" : "text"
    }

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    // Lightweight regex tinting, not a real tokenizer - strings/comments/
    // keywords/numbers get colored, everything else stays plain. Colors
    // come from the live wallust palette (not fixed hex values) so this
    // tracks whatever the current wallpaper's theme actually is, the same
    // way a themed terminal would.
    //
    // This has to be one single-pass regex, not four sequential .replace()
    // calls - the keyword list includes plain words like "color" and "font"
    // that are also substrings of the `<font color="...">` tags an earlier
    // pass would have already inserted, so a later pass matches inside its
    // own HTML and corrupts it (visibly: the hex digits and tag text itself
    // showing up as text in the preview).
    readonly property var _codeTokenPattern: /("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|(\/\/[^\n]*|#[^\n]*)|(\b(?:const|let|var|function|return|import|export|from|default|if|else|for|while|class|new|this|def|async|await|background|padding|outline|color|transition|border|margin|display|position|width|height|font|struct|impl|fn|pub|use)\b)|(\b\d+(?:\.\d+)?(?:px|em|rem|vh|vw|%|s|ms)?\b)/g
    function highlightCode(text) {
        const s = root.escapeHtml(text)
        return s.replace(root._codeTokenPattern, (match, str, comment, keyword, num) => {
            if (str !== undefined) return `<font color="${WallustColors.green}">${match}</font>`
            if (comment !== undefined) return `<font color="${WallustColors.brightBlack}">${match}</font>`
            if (keyword !== undefined) return `<font color="${WallustColors.magenta}">${match}</font>`
            if (num !== undefined) return `<font color="${WallustColors.yellow}">${match}</font>`
            return match
        })
    }

    WRectangularShadow { target: bgRect }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: SMColors.bg
        radius: 14
        antialiasing: true
        border.width: 1
        border.color: ColorUtils.applyAlpha(SMColors.fg, 0.14)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol { text: "content_paste"; iconSize: 16; color: root.accentCol }
            Text {
                Layout.fillWidth: true
                text: Translation.tr("Clipboard")
                color: root.textCol
                font.pixelSize: 16
                font.bold: true
            }
            Item {
                visible: Cliphist.entries.length > 0
                implicitWidth: 26
                implicitHeight: 26

                Rectangle {
                    anchors.centerIn: parent
                    width: clearMouse.containsMouse ? 24 : 0
                    height: width
                    radius: height / 2
                    antialiasing: true
                    color: ColorUtils.applyAlpha(root.dangerCol, 0.18)
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "delete_sweep"
                    iconSize: 15
                    color: clearMouse.containsMouse ? root.dangerCol : root.dimTextCol
                }
                MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Cliphist.wipe() }
            }

            Item {
                implicitWidth: 26
                implicitHeight: 26

                Rectangle {
                    anchors.centerIn: parent
                    width: closeMouse.containsMouse ? 24 : 0
                    height: width
                    radius: height / 2
                    antialiasing: true
                    color: ColorUtils.applyAlpha(SMColors.fg, 0.12)
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 15
                    color: root.textCol
                }
                MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32
            radius: 10
            antialiasing: true
            color: root.cardBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                MaterialSymbol { text: "search"; iconSize: 14; color: root.dimTextCol }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: root.textCol
                    font.pixelSize: 12
                    clip: true
                    selectByMouse: true
                    onTextChanged: root.searchText = text

                    Text {
                        visible: searchInput.text.length === 0
                        text: Translation.tr("Search clipboard history...")
                        color: root.dimTextCol
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MaterialSymbol {
                    visible: searchInput.text.length > 0
                    text: "close"
                    iconSize: 13
                    color: root.dimTextCol
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: searchInput.text = "" }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 40
            Layout.alignment: Qt.AlignHCenter
            visible: root.filteredEntries.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: Cliphist.entries.length === 0 ? Translation.tr("Clipboard history is empty") : Translation.tr("No matches")
            color: root.dimTextCol
            font.pixelSize: 12
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: root.filteredEntries
            ScrollBar.vertical: StyledScrollBar {}

            add: Transition {
                enabled: Looks.transition.enabled
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Looks.transition.duration.medium; easing.type: Easing.OutQuad }
                    NumberAnimation {
                        property: "scale"; from: 0.92; to: 1
                        duration: Looks.transition.duration.panel
                        easing.type: Easing.OutBack; easing.overshoot: 0.15
                    }
                }
            }
            remove: Transition {
                enabled: Looks.transition.enabled
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Looks.transition.duration.normal; easing.type: Easing.InQuad }
                    NumberAnimation { property: "scale"; from: 1; to: 0.95; duration: Looks.transition.duration.medium; easing.type: Easing.InQuad }
                }
            }
            displaced: Transition {
                enabled: Looks.transition.enabled
                NumberAnimation {
                    properties: "x,y"
                    duration: Looks.transition.duration.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                }
            }

            delegate: Rectangle {
                id: entryRow
                required property string modelData
                readonly property string id: Cliphist.idOf(modelData)
                readonly property string kind: root.entryKind(id, modelData)
                readonly property var decoded: Cliphist.contentCache[id]

                width: listView.width
                implicitHeight: col.implicitHeight + 16
                radius: 12
                antialiasing: true
                color: rowMouse.containsMouse ? root.rowHoverBg : root.cardBg

                Component.onCompleted: Cliphist.requestContent(entryRow.modelData)

                ColumnLayout {
                    id: col
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: entryRow.kind === "image" ? Translation.tr("Image") : entryRow.kind === "code" ? Translation.tr("Code") : Translation.tr("Text")
                            color: root.accentCol
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.formatTimeAgo(Cliphist.entryTimestamps[entryRow.id])
                            color: root.dimTextCol
                            font.pixelSize: 11
                        }
                        Text {
                            visible: Cliphist.sizeCache[entryRow.id] !== undefined && Cliphist.sizeCache[entryRow.id] >= 0
                            text: root.formatBytes(Cliphist.sizeCache[entryRow.id])
                            color: root.dimTextCol
                            font.pixelSize: 11
                        }
                        Item {
                            implicitWidth: 22
                            implicitHeight: 22

                            Rectangle {
                                anchors.centerIn: parent
                                width: deleteMouse.containsMouse ? 20 : 0
                                height: width
                                radius: height / 2
                                antialiasing: true
                                color: ColorUtils.applyAlpha(root.dangerCol, 0.18)
                                Behavior on width { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 13
                                color: deleteMouse.containsMouse ? root.dangerCol : root.dimTextCol
                            }
                            MouseArea {
                                id: deleteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Cliphist.deleteEntry(entryRow.modelData)
                            }
                        }
                    }

                    // Image preview
                    Rectangle {
                        visible: entryRow.kind === "image"
                        Layout.fillWidth: true
                        implicitHeight: 120
                        radius: 8
                        antialiasing: true
                        color: root.codeBg
                        clip: true

                        Image {
                            anchors.fill: parent
                            visible: entryRow.kind === "image" && entryRow.decoded !== undefined
                            // Only feed a source for actual image rows - this binds
                            // regardless of `visible`, so an ungated source here would
                            // hand text/code rows' decoded content to Image as a URL.
                            source: (entryRow.kind === "image" && entryRow.decoded !== undefined) ? entryRow.decoded : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            sourceSize: Qt.size(width * 2, height * 2)
                        }
                        Text {
                            visible: entryRow.kind === "image" && entryRow.decoded === undefined
                            anchors.centerIn: parent
                            text: Translation.tr("Loading...")
                            color: root.dimTextCol
                            font.pixelSize: 11
                        }
                    }

                    // Code preview - lightly tinted monospace block
                    Rectangle {
                        visible: entryRow.kind === "code"
                        Layout.fillWidth: true
                        implicitHeight: codeText.implicitHeight + 12
                        radius: 8
                        antialiasing: true
                        color: root.codeBg

                        Text {
                            id: codeText
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                            textFormat: Text.RichText
                            font.family: "monospace"
                            font.pixelSize: 12
                            lineHeight: 1.35
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            color: root.textCol
                            text: {
                                const full = entryRow.decoded ?? StringUtils.cleanCliphistEntry(entryRow.modelData)
                                const lines = full.split("\n").slice(0, 6).join("\n")
                                return root.highlightCode(lines)
                            }
                        }
                    }

                    // Plain text preview
                    Text {
                        visible: entryRow.kind === "text"
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        lineHeight: 1.3
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        color: root.textCol
                        font.pixelSize: 13
                        text: entryRow.decoded ?? StringUtils.cleanCliphistEntry(entryRow.modelData)
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    z: -1
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Cliphist.copy(entryRow.modelData)
                        root.close()
                    }
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
        }
    }
}
