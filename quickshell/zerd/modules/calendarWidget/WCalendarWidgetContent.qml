pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.startMenu

Rectangle {
    id: root

    readonly property color textCol: SMColors.fg
    readonly property color dimTextCol: ColorUtils.applyAlpha(SMColors.fg, 0.6)

    implicitWidth: col.implicitWidth + 32
    implicitHeight: col.implicitHeight + 28
    radius: 18
    antialiasing: true
    color: ColorUtils.applyAlpha(SMColors.bg, 0.75)
    border.width: 1
    border.color: ColorUtils.applyAlpha(SMColors.fg, 0.1)

    component IconText: Text {
        font.family: "Material Symbols Rounded"
        color: root.textCol
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: Qt.locale().toString(calendarView.focusedDate, "MMMM yyyy")
                color: root.textCol
                font.pixelSize: 15
                font.bold: true
            }
            IconText {
                text: "chevron_left"
                font.pixelSize: 18
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calendarView.scrollMonthsAndSnap(-1) }
            }
            IconText {
                text: "chevron_right"
                font.pixelSize: 18
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calendarView.scrollMonthsAndSnap(1) }
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: Qt.locale()
            spacing: calendarView.buttonSpacing
            implicitHeight: calendarView.buttonSize
            delegate: Text {
                required property var model
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                width: calendarView.buttonSize
                height: calendarView.buttonSize
                text: model.shortName.substring(0, 2)
                color: root.dimTextCol
                font.pixelSize: 11
            }
        }

        CalendarView {
            id: calendarView
            Layout.fillWidth: true
            locale: Qt.locale()
            buttonSize: 34
            buttonSpacing: 3
            verticalPadding: 2

            delegate: Rectangle {
                id: dayCell
                required property var model
                implicitWidth: calendarView.buttonSize
                implicitHeight: calendarView.buttonSize
                radius: height / 2
                antialiasing: true
                color: dayCell.model.today ? SMColors.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: dayCell.model.day
                    font.pixelSize: 12
                    color: dayCell.model.today ? SMColors.bg
                        : dayCell.model.month === calendarView.focusedMonth ? root.textCol : root.dimTextCol
                }
            }
        }
    }
}
