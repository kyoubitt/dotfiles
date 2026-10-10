pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.startMenu
import qs.modules.waffle.looks
import qs.modules.waffle.notificationPopup

Item {
    id: root

    signal closed()
    function close() { root.closed() }

    readonly property color textCol: SMColors.fg
    readonly property color dimTextCol: ColorUtils.applyAlpha(SMColors.fg, 0.65)
    // Wallust (not SMColors) drives the accent touches here, same as the
    // clipboard panel's code highlighting - both should read as coming
    // from the same "synced to the current wallpaper" palette.
    readonly property color accentCol: WallustColors.cyan
    readonly property color dangerCol: WallustColors.red

    implicitWidth: 380
    implicitHeight: Math.min(560, headerCol.implicitHeight + listView.contentHeight + 40)

    // Reported so the clipboard panel (also top-right) can stack itself
    // below this one instead of the two overlapping when both are open.
    onImplicitHeightChanged: GlobalStates.notificationCenterHeight = root.implicitHeight
    Component.onCompleted: GlobalStates.notificationCenterHeight = root.implicitHeight
    Component.onDestruction: GlobalStates.notificationCenterHeight = 0

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
            id: headerCol
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol { text: "notifications"; iconSize: 16; color: root.accentCol }
            Text {
                Layout.fillWidth: true
                text: Translation.tr("Notifications")
                color: root.textCol
                font.pixelSize: 15
                font.bold: true
            }
            Item {
                visible: Notifications.list.length > 0
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
                MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifications.discardAllNotifications() }
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

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 60
            Layout.alignment: Qt.AlignHCenter
            visible: Notifications.list.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("No notifications")
            color: root.dimTextCol
            font.pixelSize: 12
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: ScriptModel {
                values: Notifications.appNameList
            }

            // Same entrance/exit language as the popup list (WNotificationListView)
            // rather than a hard cut - this panel embeds the same WNotificationGroup
            // cards, so it should move the same way too.
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

            delegate: WNotificationGroup {
                required property int index
                required property var modelData

                width: listView.width
                notificationGroup: Notifications.groupsByAppName[modelData]
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
        } else if (event.key === Qt.Key_Delete && Notifications.list.length > 0) {
            Notifications.discardAllNotifications()
            event.accepted = true
        }
    }
}
