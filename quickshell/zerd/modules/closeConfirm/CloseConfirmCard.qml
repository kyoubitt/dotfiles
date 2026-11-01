import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bars

// "Close this window?" for Mod+Q. Enter closes it, Shift+Enter force quits a stuck app,
// Escape or a click outside cancels.
Item {
    id: root
    focus: true

    required property var targetWindow
    signal confirm()
    signal cancel()
    signal force()

    readonly property string appId: targetWindow?.app_id ?? ""
    readonly property string appTitle: targetWindow?.title ?? ""
    property bool shown: false
    Component.onCompleted: { root.shown = true; root.forceActiveFocus() }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (event.modifiers & Qt.ShiftModifier) root.force(); else root.confirm()
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.shown ? 0.34 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        MouseArea { anchors.fill: parent; onClicked: root.cancel() }
    }

    Rectangle {
        id: card
        width: 380
        height: body.implicitHeight + 48
        anchors.centerIn: parent
        radius: 28
        color: BarStyle.surface
        border.width: 1
        border.color: BarStyle.border
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        Column {
            id: body
            x: 24; y: 24
            width: parent.width - 48
            spacing: 14

            Row {
                spacing: 14
                SmartAppIcon {
                    icon: AppSearch.lookupDesktopEntry(root.appId)?.icon || AppSearch.guessIcon(root.appId)
                    iconSize: 52
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: body.width - 52 - 14
                    spacing: 2
                    BarText { text: "Close this window?"; font.pixelSize: 16; font.weight: Font.DemiBold }
                    BarText { width: parent.width; elide: Text.ElideRight; text: root.appTitle.length > 0 ? root.appTitle : root.appId; color: BarStyle.subtext; font.pixelSize: 12 }
                }
            }

            Row {
                width: parent.width
                spacing: 10
                component Btn: Rectangle {
                    id: b
                    property string label
                    property bool primary: false
                    signal tapped()
                    width: (body.width - 10) / 2; height: 44; radius: 22
                    color: area.pressed ? BarStyle.border : (primary ? BarStyle.accent : (hv.hovered ? BarStyle.plateHover : BarStyle.plate))
                    border.width: primary ? 0 : 1; border.color: BarStyle.border
                    scale: area.pressed ? 0.97 : 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    BarText { anchors.centerIn: parent; text: b.label; font.weight: Font.DemiBold; color: b.primary ? BarStyle.onAccent : BarStyle.text }
                    MouseArea { id: area; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: b.tapped() }
                    HoverHandler { id: hv }
                }
                Btn { label: "Cancel"; onTapped: root.cancel() }
                Btn { label: "Close"; primary: true; onTapped: root.confirm() }
            }

            // For an app that ignores the close request.
            Item {
                width: parent.width; height: 22
                BarText {
                    anchors.centerIn: parent
                    text: "Force quit  (Shift+Enter)"
                    font.pixelSize: 11
                    color: forceArea.containsMouse ? "#e07a6e" : BarStyle.subtext
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                MouseArea { id: forceArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.force() }
            }
        }
    }
}
