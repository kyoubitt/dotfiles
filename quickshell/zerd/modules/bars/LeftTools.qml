import QtQuick
import qs
import qs.services
import qs.modules.common

// The Tools tab of the left panel: the shell's own sections (clipboard, screenshots, notification rules, battery,
// weather, calculator, converter, notes), each one collapsible and movable.
Flickable {
    id: root

    readonly property var names: ["clipboard", "shots", "notifrules", "battery", "weather", "calculator", "converter", "notes"]
    readonly property var saved: Config.options?.bars?.sidebars?.leftOrder ?? []
    readonly property var order: root.saved.filter(n => root.names.includes(n)).concat(root.names.filter(n => !root.saved.includes(n)))

    contentWidth: width
    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Component {
        id: cClipboard
        AccordionSection {
            width: stack.width
            name: "clipboard"; icon: "content_paste"; title: "Clipboard"
            summary: "Search, pin, images"
            ClipboardSection { width: parent.width }
        }
    }
    Component {
        id: cShots
        AccordionSection {
            width: stack.width
            name: "shots"; icon: "screenshot_region"; title: "Screenshots"
            summary: "Latest shots"
            ScreenshotsSection { width: parent.width }
        }
    }
    Component {
        id: cRules
        AccordionSection {
            width: stack.width
            name: "notifrules"; icon: "notifications_paused"; title: "Notification rules"
            summary: NotifRules.raw.length + " custom"
            NotifRulesSection { width: parent.width }
        }
    }
    Component {
        id: cBattery
        AccordionSection {
            width: stack.width
            name: "battery"; icon: "battery_full"; title: "Battery"
            summary: Math.round(Battery.percentage * 100) + "%" + (Battery.isCharging ? "  ·  charging" : "")
            BatteryPopup { width: parent.width }
        }
    }
    Component {
        id: cWeather
        AccordionSection {
            width: stack.width
            name: "weather"; icon: BarStyle.weatherIcon(Weather.data.wCode); title: "Weather"
            summary: Weather.data.temp + "  ·  " + BarStyle.weatherText(Weather.data.wCode)
            WeatherPopup {}
        }
    }
    Component {
        id: cCalculator
        AccordionSection {
            width: stack.width
            name: "calculator"; icon: "calculate"; title: "Calculator"
            summary: "Keypad"
            CalculatorSection { width: parent.width }
        }
    }
    Component {
        id: cConverter
        AccordionSection {
            width: stack.width
            name: "converter"; icon: "straighten"; title: "Converter"
            summary: "Length, mass, temperature, speed"
            ConverterSection { width: parent.width }
        }
    }
    Component {
        id: cNotes
        AccordionSection {
            width: stack.width
            name: "notes"; icon: "edit_note"; title: "Notes"
            summary: "Scratch note"
            NotesSection { width: parent.width }
        }
    }

    Column {
        id: column
        width: root.width
        SectionStack {
            id: stack
            width: parent.width
            names: root.names
            order: root.order
            hidden: Battery.available ? [] : ["battery"]
            comps: ({ clipboard: cClipboard, shots: cShots, notifrules: cRules, battery: cBattery, weather: cWeather, calculator: cCalculator, converter: cConverter, notes: cNotes })
            onMoved: list => Config.options.bars.sidebars.leftOrder = list
        }
    }
}
