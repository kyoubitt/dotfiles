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

    // the search text of the panel: sections whose name or keywords do not match are left out
    property string query: ""
    readonly property var keywords: ({
        calendar: "calendar date month day agenda today",
        notifications: "notifications alerts messages clear mute",
        weather: "weather forecast temperature rain wind",
        timer: "timer stopwatch focus pomodoro countdown",
        calculator: "calculator math numbers",
        converter: "converter units length mass temperature speed data volume",
        notes: "notes scratch memo text"
    })
    function matches(name: string): bool {
        const q = root.query.trim().toLowerCase()
        if (q.length === 0) return true
        return (name + " " + (root.keywords[name] ?? "")).toLowerCase().includes(q)
    }
    readonly property var firstMatch: root.order.filter(n => !root.hidden.includes(n) && root.matches(n))[0] ?? ""

    readonly property var defaults: ["calendar", "notifications", "weather", "timer", "calculator", "converter", "notes"]
    readonly property var stored: Config.options?.bars?.sidebars?.rightOrder ?? []
    readonly property var order: root.stored.filter(n => root.defaults.includes(n)).concat(root.defaults.filter(n => !root.stored.includes(n)))
    readonly property var hidden: Config.options?.bars?.sidebars?.rightHidden ?? []

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
        hidden: root.hidden.concat(root.defaults.filter(n => !root.matches(n)))
        comps: root.comps
        onMoved: list => Config.options.bars.sidebars.rightOrder = list
    }
}
