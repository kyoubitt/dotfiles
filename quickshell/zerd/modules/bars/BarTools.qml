pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.services

// Screen recording, caffeine and night light, shared by the tools capsule and the quick panel.
// Night light goes through the shell's own Hyprsunset service: it already owns the single
// wlsunset instance, and a second one cannot take the gamma control.
Singleton {
    id: root

    readonly property bool recording: recorder.running
    readonly property bool caffeine: inhibit.running
    readonly property bool nightLight: Hyprsunset.active
    property int recordSeconds: 0
    property string recordFile: ""

    function toggleRecording(): void {
        if (recorder.running) { recorder.running = false; return }
        root.recordFile = Quickshell.env("HOME") + "/Videos/rec-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss") + ".mp4"
        root.recordSeconds = 0
        recorder.command = ["wf-recorder", "-f", root.recordFile]
        recorder.running = true
    }
    // Do not disturb while a focus lap runs; undone after, but only if this turned it on.
    property bool focusSilenced: false
    readonly property bool focusing: TimerService.pomodoroRunning && !TimerService.pomodoroPaused && !TimerService.pomodoroBreak
    onFocusingChanged: {
        if (focusing && (Config.options?.bars?.sidebars?.focusDnd ?? true) && !Notifications.silent) {
            focusSilenced = true
            Notifications.toggleSilent()
        } else if (!focusing && focusSilenced) {
            focusSilenced = false
            if (Notifications.silent) Notifications.toggleSilent()
        }
    }
    // Focus mode: do not disturb, caffeine and night light on in one tap. Leaving it puts back
    // exactly what was on before, so a night light you already had stays.
    property bool focusMode: false
    property var focusBefore: ({ silent: false, caffeine: false, night: false })
    function setFocusMode(on: bool): void {
        if (on === root.focusMode) return
        if (on) {
            root.focusBefore = { silent: Notifications.silent, caffeine: root.caffeine, night: root.nightLight }
            if (!Notifications.silent) Notifications.toggleSilent()
            if (!root.caffeine) root.toggleCaffeine()
            if (!root.nightLight) root.toggleNightLight()
        } else {
            if (Notifications.silent !== root.focusBefore.silent) Notifications.toggleSilent()
            if (root.caffeine !== root.focusBefore.caffeine) root.toggleCaffeine()
            if (root.nightLight !== root.focusBefore.night) root.toggleNightLight()
        }
        root.focusMode = on
        GlobalStates.focusMode = on
        BarState.closeAll()
        Quickshell.execDetached(["notify-send", "-a", "Focus", on ? "Focus mode on" : "Focus mode off", on ? "Do not disturb, caffeine and night light are on" : "Everything is back as it was"])
    }
    function toggleFocusMode(): void { root.setFocusMode(!root.focusMode) }
    function toggleCaffeine(): void { inhibit.running = !inhibit.running }
    function toggleNightLight(): void { Hyprsunset.toggle() }
    function clock(sec: int): string { return Math.floor(sec / 60) + ":" + (sec % 60 < 10 ? "0" : "") + (sec % 60) }

    Process {
        id: recorder
        onRunningChanged: if (!running && root.recordFile.length > 0)
            Quickshell.execDetached(["notify-send", "-a", "Screen recording", "Recording saved", root.recordFile.split("/").pop() + "  (" + root.clock(root.recordSeconds) + ")"])
    }
    Timer { interval: 1000; repeat: true; running: recorder.running; onTriggered: root.recordSeconds++ }
    Process { id: inhibit; command: ["systemd-inhibit", "--what=idle:sleep", "--who=zerd", "--why=caffeine", "sleep", "infinity"] }
}
