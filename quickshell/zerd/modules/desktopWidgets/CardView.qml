import QtQuick
import Quickshell
import qs.modules.common
import qs.services
import qs.modules.iris.host
import qs.modules.iris.widgets
import qs.modules.iris.style
import qs.modules.background.widgets.clock
import qs.modules.background.widgets.shape
import qs.modules.background.widgets.visualizer

// One desktop card by name: the live card, used on the desktop and on the arrange board.
Loader {
    id: view
    required property string name
    property var screenRef: null
    sourceComponent: ({
        media: c_media,
        clock: c_clock,
        weather: c_weather,
        wind: c_wind,
        rings: c_rings,
        greeting: c_greeting,
        calendar: c_calendar,
        agenda: c_agenda,
        controls: c_controls,
        date: c_date,
        day: c_day,
        battery: c_battery,
        uptime: c_uptime,
        worldClock: c_worldClock,
        todo: c_todo,
        timer: c_timer,
        cookieClock: c_cookieClock,
        pixelClock: c_pixelClock,
        stackedClock: c_stackedClock,
        visualizer: c_visualizer,
        shape: c_shape,
        notes: c_notes
    })[name] ?? null
    Component {
        id: c_media
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 380; height: 176
                    IrisNowPlayingFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_clock
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    options: ({ face: "digital", seconds: false })
                    scaleFactor: 0.82
                    width: 176; height: 176
                    IrisClockFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_weather
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 176; height: 176
                    IrisWeatherFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_wind
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 176; height: 176
                    WindCard { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_rings
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 366; height: 176
                    IrisVitalsFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_greeting
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 380; height: 176
                    IrisProfileFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_calendar
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 360; height: 232
                    IrisCalendarFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_agenda
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 380; height: 232
                    IrisAgendaFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_controls
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 380; height: 226
                    IrisControlsFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_date
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 176; height: 176
                    IrisDateFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_day
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 176; height: 176
                    IrisDayFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_battery
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 176; height: 176
                    IrisBatteryFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_uptime
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 176; height: 176
                    IrisUptimeFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_worldClock
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 380; height: 176
                    IrisWorldClockFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_todo
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 300; height: 290
                    IrisTodoFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_timer
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 380; height: 176
                    IrisTimerFace { widget: host; anchors.fill: parent }
                }
                }
    Component {
        id: c_cookieClock
                CookieClock {
                    colBackground: Qt.rgba(WallustTheme.bgBase.r, WallustTheme.bgBase.g, WallustTheme.bgBase.b, 1)
                    colOnBackground: WallustTheme.textPrimary
                    colBackgroundInfo: WallustTheme.textSecondary
                    colHourHand: WallustTheme.accent
                    colMinuteHand: WallustTheme.textPrimary
                    colSecondHand: WallustTheme.accent
                }
                }
    Component {
        id: c_pixelClock
                PixelClock {
                    currentDate: DateTime.clock.date
                    softColor: WallustTheme.bgBase
                    boldColor: WallustTheme.accent
                }
                }
    Component {
        id: c_stackedClock
                AndroidStackedClock {
                    currentDate: DateTime.clock.date
                    timeText: Qt.locale().toString(DateTime.clock.date, "hh:mm")
                    timeColor: WallustTheme.textPrimary
                    dateColor: WallustTheme.textSecondary
                    haloColor: "transparent"
                    fontFamily: Appearance.font.family.expressive
                }
                }
    Component {
        id: c_visualizer
        VisualizerWidget {}
    }
    Component {
        id: c_shape
        ShapeWidget {}
    }
    Component {
        id: c_notes
                IrisWidgetHost {
                    id: host
                    screenRef: view.screenRef
                    width: 300; height: 220
                    noteText: noteEdit.text
                    IrisNotesFace { widget: host; anchors.fill: parent }
                    TextEdit {
                        id: noteEdit
                        anchors { fill: parent; margins: 18; topMargin: 46 }
                        color: IrisStyle.text
                        selectionColor: IrisStyle.accent
                        font.family: IrisStyle.fontMain
                        font.pixelSize: 14
                        wrapMode: TextEdit.Wrap
                        clip: true
                        text: Config.options?.desktopWidgets?.notes?.text ?? ""
                        onTextChanged: saveTimer.restart()
                        Timer {
                            id: saveTimer
                            interval: 700
                            onTriggered: {
                                const node = Config.options?.desktopWidgets?.notes
                                if (node && node.text !== noteEdit.text) node.text = noteEdit.text
                            }
                        }
                    }
                }
                }
}
