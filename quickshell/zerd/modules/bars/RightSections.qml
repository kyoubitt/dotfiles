import QtQuick
import qs
import qs.services
import qs.modules.common

// The right panel: the widget-board button and collapsible sections. Time, date, toggles and the
// like live in the quick panel, so none of that is repeated here.
// Order and visibility can be set in `bars.sidebars.rightOrder` / `rightHidden`.
Column {
    id: root

    spacing: 10

    readonly property var defaults: ["calendar", "notifications", "weather", "timer", "calculator", "converter", "notes"]
    readonly property var stored: Config.options?.bars?.sidebars?.rightOrder ?? []
    readonly property var order: root.stored.filter(n => root.defaults.includes(n)).concat(root.defaults.filter(n => !root.stored.includes(n)))
    readonly property var hidden: Config.options?.bars?.sidebars?.rightHidden ?? []

    // One button; the cards themselves are added and moved on the board.
    Rectangle {
        width: parent.width; height: 44; radius: 22
        color: editArea.pressed ? BarStyle.border : BarStyle.plateHover
        border.width: 1; border.color: BarStyle.border
        Behavior on color { ColorAnimation { duration: 100 } }
        Row {
            anchors.centerIn: parent; spacing: 8
            BarIcon { name: "widgets"; size: 18; color: BarStyle.accent }
            BarText { text: "Edit widgets"; font.weight: Font.DemiBold }
        }
        MouseArea { id: editArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: BarState.openBoard() }
    }

    // ---- Sections
    Component {
        id: cCalendar
        AccordionSection {
            width: root.width
            name: "calendar"; icon: "calendar_month"; title: "Calendar"
            summary: Qt.formatDate(new Date(), "dddd, d MMMM")
            CalendarCard { cellW: Math.floor((parent.width - 36) / 7) }
        }
    }
    Component {
        id: cWeather
        AccordionSection {
            width: root.width
            name: "weather"; icon: BarStyle.weatherIcon(Weather.data.wCode); title: "Weather"
            summary: Weather.data.temp + "  ·  " + BarStyle.weatherText(Weather.data.wCode)
            WeatherPopup {}
        }
    }
    Component {
        id: cNotifications
        AccordionSection {
            width: root.width
            name: "notifications"; icon: "notifications"; title: "Notifications"
            summary: Notifications.count > 0 ? Notifications.count + " new" : "All caught up"
            NotificationsPopup { width: parent.width; compact: true }
        }
    }
    Component {
        id: cTimer
        AccordionSection {
            width: root.width
            name: "timer"; icon: "timer"; title: "Timer and focus"
            summary: TimerService.pomodoroRunning ? "Focus session running" : (TimerService.countdownRunning ? "Running" : (TimerService.stopwatchRunning ? "Stopwatch running" : "Countdown, stopwatch, focus"))
            TimerSection { width: parent.width }
        }
    }
    Component {
        id: cCalculator
        AccordionSection {
            width: root.width
            name: "calculator"; icon: "calculate"; title: "Calculator"
            summary: "Keypad"
            CalculatorSection { width: parent.width }
        }
    }
    Component {
        id: cConverter
        AccordionSection {
            width: root.width
            name: "converter"; icon: "straighten"; title: "Converter"
            summary: "Length, mass, temperature, speed"
            ConverterSection { width: parent.width }
        }
    }
    Component {
        id: cNotes
        AccordionSection {
            width: root.width
            name: "notes"; icon: "edit_note"; title: "Notes"
            summary: "Scratch note"
            NotesSection { width: parent.width }
        }
    }
    readonly property var comps: ({
        calendar: cCalendar, notifications: cNotifications, weather: cWeather, timer: cTimer, calculator: cCalculator, converter: cConverter, notes: cNotes
    })

    SectionStack {
        width: parent.width
        names: root.defaults
        order: root.order
        hidden: root.hidden
        comps: root.comps
        onMoved: list => Config.options.bars.sidebars.rightOrder = list
    }
}
