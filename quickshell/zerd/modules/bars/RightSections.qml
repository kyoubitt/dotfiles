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

    readonly property var defaults: ["calendar", "notifications", "weather", "timer", "calculator", "converter", "translate", "notes"]
    readonly property var stored: Config.options?.bars?.sidebars?.rightOrder ?? []
    readonly property var order: root.stored.filter(n => root.defaults.includes(n)).concat(root.defaults.filter(n => !root.stored.includes(n)))
    readonly property var hidden: Config.options?.bars?.sidebars?.rightHidden ?? []

    // One button; the cards themselves are added and moved on the board.
    BarButton {
        id: editBtn
        tone: "tonal"
        width: parent.width; height: 48; radius: height / 2
        onTapped: BarState.openBoard()
        Row {
            anchors.centerIn: parent; spacing: 8
            BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "widgets"; size: 18; fill: 1; color: BarStyle.accent }
            BarText { anchors.verticalCenter: parent.verticalCenter; text: "Edit widgets"; font.weight: Font.DemiBold; color: editBtn.ink }
        }
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
        id: cTranslate
        AccordionSection {
            width: root.width
            name: "translate"; icon: "translate"; title: "Translate"
            summary: "Type or paste, pick the languages"
            Translator { width: parent.width; height: 420 }
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
        calendar: cCalendar, notifications: cNotifications, weather: cWeather, timer: cTimer, calculator: cCalculator, converter: cConverter, translate: cTranslate, notes: cNotes
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
