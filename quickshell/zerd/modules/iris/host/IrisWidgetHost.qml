import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.services
import qs.modules.iris.widgets

// The `widget` object iNiR's iRiS faces read their settings from. iNiR's own
// host is a full desktop-widget canvas with placement, stacks and editing;
// this one only answers what the faces ask: size, colours, material, data.
// Put a face inside it: IrisWidgetHost { IrisClockFace { widget: parent } }
Item {
    id: root

    default property alias content: slot.data

    // "small" | "medium" | "large"
    property string irisSize: "medium"
    property var options: ({})
    property var screenRef: null
    property string outputName: screenRef?.name ?? ""
    property real screenWidth: screenRef?.width ?? 1920
    property real screenHeight: screenRef?.height ?? 1080

    // Palette: the wallust colours of the current wallpaper.
    // the shell's second surface layer, so a card matches the panels and notifications
    property color irisPlate: Appearance.colors.colLayer2
    property color irisAccent: WallustTheme.accent
    property color irisAccent2: WallustColors.green
    property color irisAccent3: WallustTheme.accent
    property color identityTint: WallustTheme.accent

    // Material: an opaque plate, never wallpaper glass.
    property string irisMaterial: "panel"
    property real irisSurfaceOpacity: 0.95
    property string irisOutline: "always"
    property bool irisRim: false
    property bool legibleAlways: true
    property bool inkOnLight: false
    property bool forceDarkInk: false
    property real regionBrightness: 0.3
    property real regionBrightnessSpread: 0.1

    property real scaleFactor: 1
    property int widgetCardRadius: 23     // the shell's large corner (BarStyle.radiusLarge)
    property int cornerRadiusOverride: -1
    property int widgetTitleWeight: Font.DemiBold
    property string timeFormat: "system"

    property bool powerActive: true
    property bool motionActive: visible
    property bool animationsActive: true
    property bool locked: true
    property bool containsPress: false

    // No stacks, editing or placement.
    property bool stacked: false
    property bool stackShown: true
    property real stackPos: 0
    property var stack: ({ id: "", keys: [] })
    property var stackDropHint: null
    property string placementStrategy: "free"

    // Optional parts of the cards
    property bool showWeather: true
    property bool showLabels: true
    property bool showAvatar: true
    property bool showLocation: Config.options?.desktopWidgets?.showWeatherCity ?? false
    property bool showHostname: false
    property bool showMeta: true
    property bool showNames: true
    property bool showOffsets: true

    property var irisSizeChoices: ["small", "medium", "large"]
    property var irisSizeLabels: ({ small: "Small", medium: "Medium", large: "Large" })

    function irisOption(key: string, fallback: var): var {
        return options[key] !== undefined ? options[key] : fallback
    }
    function lockScreen(): void { Session.lock() }
    function setIrisOption(key: string, value: var): void {}
    function commitIrisValue(key: string, value: var): void {}
    function commitIrisSize(size: string): void {}
    function previewIrisValue(key: string, value: var): void {}
    function _setOutputValue(key: string, value: var): void {}
    function _readConfigKey(key: string): var { return undefined }


    // ---- state for the calendar / date / day / uptime / battery / timer / to-do /
    // ---- world clock / notes cards (the same values iNiR's own hosts compute)
    readonly property date today: DateTime.clock.date

    // Calendar
    property int monthShift: 0
    readonly property int weekStart: Qt.locale().firstDayOfWeek % 7
    property bool showAdjacentDays: false
    readonly property date viewingDate: {
        const date = new Date(root.today)
        date.setDate(1)
        date.setMonth(date.getMonth() + root.monthShift)
        return date
    }
    function monthCells(): var {
        const year = viewingDate.getFullYear()
        const month = viewingDate.getMonth()
        const first = new Date(year, month, 1)
        const startOffset = (first.getDay() - root.weekStart + 7) % 7
        const daysInMonth = new Date(year, month + 1, 0).getDate()
        const daysInPrevMonth = new Date(year, month, 0).getDate()
        const cells = []
        for (let i = 0; i < startOffset; ++i)
            cells.push({ day: daysInPrevMonth - startOffset + i + 1, currentMonth: false, isToday: false })
        for (let day = 1; day <= daysInMonth; ++day)
            cells.push({
                day: day,
                currentMonth: true,
                isToday: year === root.today.getFullYear() && month === root.today.getMonth() && day === root.today.getDate()
            })
        let nextDay = 1
        while (cells.length < 42)
            cells.push({ day: nextDay++, currentMonth: false, isToday: false })
        return cells
    }

    // Agenda
    property bool groupByDay: true
    readonly property var upcomingEvents: IrisFaceData.upcomingEvents(root.today, 30)

    // Date
    property bool showOrdinal: true
    property bool showWeekday: true
    property bool showYear: true
    readonly property int dayOfYear: {
        const year = root.today.getFullYear()
        const current = Date.UTC(year, root.today.getMonth(), root.today.getDate())
        return Math.floor((current - Date.UTC(year, 0, 0)) / 86400000)
    }
    readonly property int daysInYear: {
        const year = root.today.getFullYear()
        return ((year % 4 === 0 && year % 100 !== 0) || year % 400 === 0) ? 366 : 365
    }

    // Day progress
    readonly property real dayFraction: (today.getHours() * 3600 + today.getMinutes() * 60 + today.getSeconds()) / 86400
    readonly property bool isDaytime: today.getHours() >= 6 && today.getHours() < 19

    // Uptime
    property bool showSince: true
    property bool showBreakdown: true
    readonly property int sessionSeconds: {
        const m = String(DateTime.uptime).match(/(\d+)d/)
        const h = String(DateTime.uptime).match(/(\d+)h/)
        const min = String(DateTime.uptime).match(/(\d+)m/)
        return Number(m?.[1] ?? 0) * 86400 + Number(h?.[1] ?? 0) * 3600 + Number(min?.[1] ?? 0) * 60
    }
    readonly property int sessionDay: Math.max(1, Math.floor(sessionSeconds / 86400) + 1)
    readonly property string bootLabel: Qt.locale().toString(new Date(today.getTime() - sessionSeconds * 1000), "HH:mm")

    // Battery
    readonly property string timeLabel: {
        const secs = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty
        if (secs <= 0) return ""
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        const text = h > 0 && m > 0 ? h + "h " + m + "m" : h > 0 ? h + "h" : m + "m"
        return Translation.tr("%1 remaining").arg(text)
    }

    // Timer
    function formatSeconds(seconds: real): string {
        const total = Math.max(0, Math.floor(Number(seconds) || 0))
        return Math.floor(total / 60).toString().padStart(2, "0") + ":" + (total % 60).toString().padStart(2, "0")
    }

    // To-do
    property bool showCompleted: true
    readonly property int pendingCount: Todo.list.filter(item => !item.done).length
    readonly property var taskEntries: Todo.list.map((item, originalIndex) => ({
        content: item.content,
        done: item.done,
        originalIndex: originalIndex
    }))

    // World clock
    readonly property var cities: WorldClock.entries
    function cityDayDelta(index: int): int {
        const cityDate = WorldClock.cityDisplayDate(index)
        if (!cityDate) return 0
        return Math.round((Date.UTC(cityDate.getFullYear(), cityDate.getMonth(), cityDate.getDate())
            - Date.UTC(WorldClock.now.getFullYear(), WorldClock.now.getMonth(), WorldClock.now.getDate())) / 86400000)
    }

    // Notes (edited by the text box the layer puts on top of the card)
    property string noteText: ""

    // Weather
    readonly property string temperatureText: Weather.data.temp

    // Vitals
    readonly property var _resourceModel: {
        const rows = [{ key: "cpu", label: "CPU" }, { key: "mem", label: "RAM" }]
        if (ResourceUsage.gpuAvailable) rows.push({ key: "gpu", label: "GPU" })
        rows.push({ key: "disk", label: "Disk" })
        return rows
    }
    function _getValue(key: string): real {
        switch (key) {
        case "cpu": return ResourceUsage.cpuUsage
        case "mem": return ResourceUsage.memoryUsedPercentage
        case "gpu": return ResourceUsage.gpuUsage
        case "disk": return ResourceUsage.diskUsedPercentage
        case "temp": return ResourceUsage.tempPercentage
        default: return 0
        }
    }
    function _getDisplayText(key: string): string {
        if (key === "temp") return Math.round(ResourceUsage.cpuTemp) + "°C"
        return Math.round(_getValue(key) * 100) + "%"
    }
    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

    Item {
        id: slot
        anchors.fill: parent
    }
}
