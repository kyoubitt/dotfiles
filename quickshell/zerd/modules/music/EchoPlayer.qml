pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Orbit's own player: librespot (Spotify's open-source player, a small process) shows up as a Spotify Connect device
// called "Orbit". Using it means the heavy Spotify desktop app can stay closed. It is optional: with the engine set
// to "app" Orbit just drives the Spotify app you already have.
Singleton {
    id: root

    readonly property string engine: Config.options?.music?.engine ?? "app"      // "app" | "echo"
    readonly property bool wanted: root.engine === "echo"
    property bool installed: false
    readonly property bool running: proc.running
    property string note: ""
    readonly property string cache: Quickshell.env("HOME") + "/.cache/echo/librespot"

    Process {
        id: probe
        command: ["sh", "-c", "command -v librespot"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.installed = text.trim().length > 0 }
    }
    function start(): void {
        if (!root.installed) { root.note = "librespot is not installed (sudo pacman -S librespot)"; return }
        if (proc.running) return
        root.note = ""
        proc.command = ["sh", "-c", "mkdir -p \"$HOME/.cache/echo\"; exec librespot --name Orbit --device-type computer --backend pulseaudio --bitrate 320 --cache \"$HOME/.cache/echo/librespot\" --initial-volume 60 --disable-audio-cache 2>> \"$HOME/.cache/echo/librespot.log\""]
        proc.running = true
    }
    function stop(): void { proc.running = false }
    Process {
        id: proc
        stdout: SplitParser { onRead: line => { if (line.includes("http") && line.includes("accounts.spotify.com")) { root.note = "Sign in in the browser window that opened"; } } }
        stderr: SplitParser { onRead: line => { if (/error/i.test(line)) root.note = line.slice(0, 120) } }
        onRunningChanged: if (!running) root.note = root.note.length > 0 ? root.note : ""
    }

    // Makes sure the Echo device is awake and selected, then runs `done`.
    function ready(done: var): void {
        if (root.engine === "soloist") { SoloistPlayer.ready(done); return }
        if (!root.wanted) { done(); return }
        root.start()
        let tries = 0
        const poll = () => MusicApi.devices(list => {
            const d = list.find(x => x.name === "Orbit")
            if (d) { if (d.is_active) done(); else MusicApi.call("PUT", "/me/player", { device_ids: [d.id], play: false }, () => Qt.callLater(done)) }
            else if (++tries < 16) pollTimer.restart(); else { root.note = "The Orbit player did not start"; done() }
        })
        pollTimer.callback = poll
        poll()
    }
    Timer { id: pollTimer; interval: 700; property var callback: null; onTriggered: if (callback) callback() }
}
