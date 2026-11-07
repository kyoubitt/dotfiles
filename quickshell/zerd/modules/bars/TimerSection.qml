import QtQuick
import qs.services

// Countdown and stopwatch, backed by the shell's TimerService (so they keep running with the panel closed).
Column {
    id: root

    property string tab: "countdown"
    spacing: 10

    function clock(sec: int): string {
        const m = Math.floor(sec / 60), s = sec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
    function stopwatchText(t: int): string {
        const cs = t % 100, s = Math.floor(t / 100) % 60, m = Math.floor(t / 6000)
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s + "." + (cs < 10 ? "0" : "") + cs
    }

    Row {
        spacing: 6
        Repeater {
            model: [{ id: "countdown", label: "Timer" }, { id: "stopwatch", label: "Stopwatch" }, { id: "focus", label: "Focus" }]
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: root.tab === modelData.id
                width: (root.width - 12) / 3; height: 30; radius: 15
                color: on ? BarStyle.accent : BarStyle.cardHigh
                Behavior on color { ColorAnimation { duration: 100 } }
                BarText { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 12; color: parent.on ? BarStyle.onAccent : BarStyle.text }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = modelData.id }
            }
        }
    }

    component Btn: Rectangle {
        id: b
        property string icon
        property bool primary: false
        signal tapped()
        width: primary ? 56 : 40; height: primary ? 56 : 40; radius: width / 2
        color: primary ? BarStyle.accent : (m.pressed ? BarStyle.border : BarStyle.cardHigh)
        Behavior on color { ColorAnimation { duration: 100 } }
        BarIcon { anchors.centerIn: parent; name: b.icon; size: primary ? 26 : 20; fill: 1; color: primary ? BarStyle.onAccent : BarStyle.text }
        MouseArea { id: m; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: b.tapped() }
    }

    // Countdown
    Column {
        visible: root.tab === "countdown"
        width: parent.width
        spacing: 10
        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: root.clock(TimerService.countdownSecondsLeft); font.pixelSize: 40; font.weight: Font.DemiBold }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            Btn { icon: "remove"; opacity: TimerService.countdownRunning ? 0.4 : 1; onTapped: if (!TimerService.countdownRunning) TimerService.adjustCountdownDuration(-60) }
            Btn { icon: TimerService.countdownRunning && !TimerService.countdownPaused ? "pause" : "play_arrow"; primary: true; onTapped: TimerService.toggleCountdown() }
            Btn { icon: "add"; opacity: TimerService.countdownRunning ? 0.4 : 1; onTapped: if (!TimerService.countdownRunning) TimerService.adjustCountdownDuration(60) }
            Btn { icon: "restart_alt"; onTapped: TimerService.resetCountdown() }
        }
    }

    // Stopwatch
    Column {
        visible: root.tab === "stopwatch"
        width: parent.width
        spacing: 10
        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: root.stopwatchText(TimerService.stopwatchTime); font.pixelSize: 36; font.weight: Font.DemiBold }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            Btn { icon: "flag"; onTapped: TimerService.stopwatchRecordLap() }
            Btn { icon: TimerService.stopwatchRunning && !TimerService.stopwatchPaused ? "pause" : "play_arrow"; primary: true; onTapped: TimerService.toggleStopwatch() }
            Btn { icon: "restart_alt"; onTapped: TimerService.stopwatchReset() }
        }
        Repeater {
            model: (TimerService.stopwatchLaps ?? []).slice(-4).reverse()
            delegate: BarText { required property var modelData; required property int index; anchors.horizontalCenter: parent.horizontalCenter; text: "Lap " + ((TimerService.stopwatchLaps?.length ?? 0) - index) + "   " + root.stopwatchText(modelData); font.pixelSize: 12; color: BarStyle.subtext }
        }
    }

    // Focus (pomodoro): work and break laps from the shell's TimerService. Do not disturb follows it (see BarTools).
    Column {
        visible: root.tab === "focus"
        width: parent.width
        spacing: 10
        BarText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: !TimerService.pomodoroRunning ? "Ready" : (TimerService.pomodoroBreak ? (TimerService.pomodoroLongBreak ? "Long break" : "Break") : "Focus") + (TimerService.pomodoroPaused ? "  ·  paused" : "")
            color: TimerService.pomodoroRunning && !TimerService.pomodoroBreak ? BarStyle.accent : BarStyle.subtext
            font.pixelSize: 12
        }
        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: root.clock(TimerService.pomodoroSecondsLeft); font.pixelSize: 40; font.weight: Font.DemiBold }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Repeater {
                model: TimerService.cyclesBeforeLongBreak
                delegate: Rectangle {
                    required property int index
                    width: 8; height: 8; radius: 4
                    color: index < TimerService.pomodoroCycle ? BarStyle.accent : BarStyle.border
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            Btn { icon: TimerService.pomodoroRunning && !TimerService.pomodoroPaused ? "pause" : "play_arrow"; primary: true; onTapped: TimerService.togglePomodoro() }
            Btn { icon: "restart_alt"; onTapped: TimerService.stopPomodoro() }
        }
        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(TimerService.focusTime / 60) + " min focus  ·  " + Math.round(TimerService.breakTime / 60) + " min break"; font.pixelSize: 11; color: BarStyle.subtext }
    }
}
