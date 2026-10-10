pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.startMenu

Item {
    id: root

    required property string appId
    required property var toplevels

    signal closed()
    function close() { closeAnim.start() }

    readonly property var desktopEntry: DesktopEntries.byId(root.appId) ?? DesktopEntries.heuristicLookup(root.appId)
    readonly property bool pinned: DockPins.isAppPinned(root.appId)

    implicitHeight: col.implicitHeight + 8

    focus: true
    Keys.onEscapePressed: root.close()

    opacity: 0
    scale: 0.92
    transformOrigin: Item.TopLeft
    Component.onCompleted: openAnim.start()

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 130; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; to: 1; duration: 150; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 0; duration: 100; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "scale"; to: 0.92; duration: 100; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: root.closed() }
    }

    // Declared here (a direct child of root), not nested inside the Column
    // below - inline `component` blocks in this codebase are only ever
    // declared at that top level (see WSideDockContent.qml's DockFlatIcon/
    // GhostPill/etc.), not inside an arbitrary nested layout.
    component MenuRow: Rectangle {
        id: menuRow
        required property string label
        required property string glyph
        property color fg: SMColors.fg
        signal activated()

        implicitHeight: 34
        radius: 8
        antialiasing: true
        color: rowMouse.containsMouse ? ColorUtils.mix(SMColors.fg, SMColors.bg, 0.14) : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            MaterialSymbol { text: menuRow.glyph; iconSize: 15; color: menuRow.fg }
            WText {
                Layout.fillWidth: true
                text: menuRow.label
                color: menuRow.fg
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menuRow.activated()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        antialiasing: true
        color: SMColors.bg
        border.width: 1
        border.color: ColorUtils.applyAlpha(SMColors.fg, 0.18)

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2

            MenuRow {
                width: col.width
                label: root.pinned ? Translation.tr("Unpin") : Translation.tr("Pin")
                glyph: root.pinned ? "close" : "push_pin"
                onActivated: {
                    DockPins.toggleAppPin(root.appId)
                    root.close()
                }
            }

            MenuRow {
                width: col.width
                visible: root.toplevels.length === 0
                label: Translation.tr("Open")
                glyph: "open_in_new"
                onActivated: {
                    root.desktopEntry?.execute()
                    root.close()
                }
            }

            MenuRow {
                width: col.width
                visible: root.toplevels.length > 0
                label: root.toplevels.length > 1 ? Translation.tr("Close all windows") : Translation.tr("Close window")
                glyph: "close"
                fg: "#E58C8C"
                onActivated: {
                    for (const t of root.toplevels) t.close()
                    root.close()
                }
            }
        }
    }
}
