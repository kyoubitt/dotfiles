import QtQuick
import qs.services

// Month grid with week numbers, a dot on days that have events, a Today button,
// the selected day's events with delete, and a one-line add box.
Column {
    id: cal

    property date shown: new Date()
    property date selected: new Date()
    property int cellW: 30
    readonly property int first: (new Date(shown.getFullYear(), shown.getMonth(), 1).getDay() + 6) % 7
    readonly property int days: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()
    readonly property int rowsNeeded: Math.ceil((first + days) / 7)
    readonly property var dayEvents: { Events.list; return Events.getEventsForDate(cal.selected) }
    spacing: 8

    function sameDay(a: date, b: date): bool { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }
    function isoWeek(d: date): int {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const n = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - n)
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7)
    }
    function today(): void { cal.shown = new Date(); cal.selected = new Date() }

    Item {
        width: 24 + cal.cellW * 7 + 12; height: 24
        BarIcon { x: 0; anchors.verticalCenter: parent.verticalCenter; name: "chevron_left"; MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: cal.shown = new Date(cal.shown.getFullYear(), cal.shown.getMonth() - 1, 1) } }
        BarText { anchors.centerIn: parent; text: Qt.formatDate(cal.shown, "MMMM yyyy"); font.weight: Font.DemiBold }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
            Rectangle {
                visible: !cal.sameDay(cal.shown, new Date()) || !cal.sameDay(cal.selected, new Date())
                width: todayText.implicitWidth + 14; height: 22; radius: 11; color: BarStyle.plateHover
                BarText { id: todayText; anchors.centerIn: parent; text: "Today"; font.pixelSize: 11 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cal.today() }
            }
            BarIcon { name: "chevron_right"; MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: cal.shown = new Date(cal.shown.getFullYear(), cal.shown.getMonth() + 1, 1) } }
        }
    }

    Grid {
        columns: 8; spacing: 2
        BarText { text: "wk"; width: 24; horizontalAlignment: Text.AlignHCenter; color: BarStyle.subtext; font.pixelSize: 10 }
        Repeater { model: ["M", "T", "W", "T", "F", "S", "S"]; delegate: BarText { required property string modelData; text: modelData; width: cal.cellW; horizontalAlignment: Text.AlignHCenter; color: BarStyle.subtext; font.pixelSize: 11 } }
        Repeater {
            model: 48
            delegate: Item {
                required property int index
                readonly property int row: Math.floor(index / 8)
                readonly property int col: index % 8
                readonly property int day: (row * 7 + col - 1) - cal.first + 1
                readonly property date cellDate: new Date(cal.shown.getFullYear(), cal.shown.getMonth(), day)
                readonly property bool valid: col > 0 && day >= 1 && day <= cal.days
                readonly property bool isToday: valid && cal.sameDay(cellDate, new Date())
                readonly property bool isSelected: valid && cal.sameDay(cellDate, cal.selected)
                readonly property bool hasEvents: valid && (Events.list, Events.getEventsForDate(cellDate).length > 0)
                width: col === 0 ? 24 : cal.cellW; height: 26
                visible: row < cal.rowsNeeded
                // Week number at the start of each row.
                BarText { visible: parent.col === 0 && parent.row < 6 && (parent.row * 7 - cal.first + 1) <= cal.days; anchors.centerIn: parent; text: cal.isoWeek(new Date(cal.shown.getFullYear(), cal.shown.getMonth(), Math.max(1, parent.row * 7 - cal.first + 1))); color: BarStyle.subtext; font.pixelSize: 10 }
                Rectangle {
                    visible: parent.valid
                    anchors.fill: parent; radius: height / 2
                    color: parent.isToday ? BarStyle.accent : (parent.isSelected ? BarStyle.plateHover : (dayAreaHv.hovered ? BarStyle.plateHover : "transparent"))
                    border.width: parent.isSelected && !parent.isToday ? 1 : 0
                    border.color: BarStyle.accent
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                BarText { visible: parent.valid; anchors.centerIn: parent; text: parent.day; color: parent.isToday ? BarStyle.onAccent : BarStyle.text; font.pixelSize: 12 }
                Rectangle { visible: parent.hasEvents; width: 4; height: 4; radius: 2; x: Math.round(parent.width / 2 - 2); y: parent.height - 6; color: parent.isToday ? BarStyle.onAccent : BarStyle.accent }
                MouseArea { id: dayArea; anchors.fill: parent; enabled: parent.valid; cursorShape: Qt.PointingHandCursor; onClicked: cal.selected = parent.cellDate }
                HoverHandler { id: dayAreaHv }
            }
        }
    }

    // Selected day
    Column {
        width: 24 + cal.cellW * 7 + 12
        spacing: 4
        BarText { text: cal.sameDay(cal.selected, new Date()) ? "Today" : Qt.formatDate(cal.selected, "dddd, d MMMM"); font.pixelSize: 11; color: BarStyle.subtext }
        BarText { visible: cal.dayEvents.length === 0; text: "Nothing planned"; font.pixelSize: 12; color: BarStyle.subtext }
        Repeater {
            model: cal.dayEvents
            delegate: Item {
                required property var modelData
                width: parent.width; height: 26
                Rectangle { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: BarStyle.accent }
                BarText { x: 14; anchors.verticalCenter: parent.verticalCenter; text: modelData.allDay ? "all day" : Qt.formatTime(new Date(modelData.dateTime), "hh:mm"); color: BarStyle.subtext; font.pixelSize: 12; width: 48 }
                BarText { x: 66; anchors.verticalCenter: parent.verticalCenter; text: modelData.title; font.pixelSize: 12; width: parent.width - 66 - 24; elide: Text.ElideRight }
                BarIcon { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; name: "close"; size: 14; color: BarStyle.subtext
                    MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: Events.remove(String(modelData.id)) } }
            }
        }
        // "18:30 dinner" or just "dentist" (all day)
        Rectangle {
            width: parent.width; height: 32; radius: 16
            color: BarStyle.plateHover
            border.width: 1; border.color: addInput.activeFocus ? BarStyle.accent : BarStyle.border
            BarText { x: 14; anchors.verticalCenter: parent.verticalCenter; visible: addInput.text.length === 0; text: "Add event  (e.g. 18:30 dinner)"; color: BarStyle.subtext; font.pixelSize: 12 }
            TextInput {
                id: addInput
                x: 14; width: parent.width - 28; height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                color: BarStyle.text
                font.pixelSize: 12
                clip: true
                onAccepted: {
                    const m = /^(\d{1,2}:\d{2})\s+(.+)$/.exec(text.trim())
                    const d = cal.selected
                    const day = d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate()
                    if (text.trim().length > 0) Events.add(m ? m[2] : text.trim(), day, m ? m[1] : "")
                    text = ""
                }
            }
        }
    }
}
