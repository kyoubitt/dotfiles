pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.dock
import qs.modules.iris.style
import qs.modules.iris.pieces

// The plate and icons of a classic dock, in one of three styles:
//   macos : no plate to speak of, strong magnification, bounce on launch
//   pill  : rounded floating plate, light magnification
//   panel : a full-width strip along the edge, no magnification
// Pins and order come from the iRiS dock (IrisDockOrder); running apps get a dot.
Item {
    id: root

    property string style: "macos"
    property int iconSize: 44
    property real pointer: -1
    property var screen: null
    property var controls: []
    readonly property bool magnify: style !== "panel"
    readonly property real gain: style === "macos" ? 0.55 : 0.25

    readonly property var apps: IrisDockOrder.entries.filter(e => e.appId !== "SEPARATOR")
    readonly property int slot: iconSize + (style === "panel" ? 14 : 10)
    readonly property int pad: style === "panel" ? 18 : 12

    implicitWidth: style === "panel" ? parent.width : apps.length * slot + 2 * pad
    implicitHeight: iconSize + 2 * pad + (style === "macos" ? 0 : 0)

    DockControls {
        visible: root.controls.length > 0
        screen: root.screen
        controls: root.controls
        anchors.left: parent.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
    }

    // Plate
    Rectangle {
        anchors.fill: parent
        radius: root.style === "panel" ? 0 : root.style === "pill" ? height / 2 : Math.round(height * 0.34)
        antialiasing: true
        color: root.style === "macos" ? Qt.rgba(IrisStyle.bodySurface.r, IrisStyle.bodySurface.g, IrisStyle.bodySurface.b, 0.55)
             : IrisStyle.bodySurface
        border.width: 1
        border.color: IrisStyle.hairline
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: mouse => root.pointer = mouse.x
        onExited: root.pointer = -1
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round((root.width - width) / 2)
        spacing: 0
        Repeater {
            model: root.apps
            delegate: Item {
                id: cell
                required property var modelData
                readonly property real centre: x + row.x + width / 2
                readonly property real near: root.magnify && root.pointer >= 0
                    ? Math.max(0, 1 - Math.abs(root.pointer - centre) / (root.slot * 2.2)) : 0
                readonly property real lift: near * near * root.gain
                readonly property bool running: (modelData.toplevels?.length ?? 0) > 0
                property real bounce: 0
                width: root.slot
                height: root.slot

                SmartAppIcon {
                    id: icon
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(cell.bounce)
                    icon: IrisPieces.appIcon(cell.modelData.appId)
                    iconSize: root.iconSize
                    transformOrigin: Item.Bottom
                    scale: 1 + cell.lift
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    visible: cell.running
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 1
                    width: 4; height: 4; radius: 2
                    color: IrisStyle.text
                    opacity: 0.8
                }
                SequentialAnimation {
                    id: hop
                    NumberAnimation { target: cell; property: "bounce"; to: 14; duration: 140; easing.type: Easing.OutCubic }
                    NumberAnimation { target: cell; property: "bounce"; to: 0; duration: 180; easing.type: Easing.InCubic }
                    loops: 2
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        const tl = cell.modelData.toplevels ?? []
                        if (tl.length > 0 && mouse.button === Qt.LeftButton) { tl[0].activate(); return }
                        if (root.style === "macos") hop.start()
                        AppSearch.launchEntry(AppSearch.lookupDesktopEntry(cell.modelData.appId))
                    }
                }
            }
        }
    }
}
