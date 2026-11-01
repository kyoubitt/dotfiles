pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.services

// What is using the screen or the microphone right now: a screen recorder, OBS,
// a screen share (any app reading a video stream from PipeWire) or the mic.
Singleton {
    id: root

    property bool obsRunning: false
    readonly property var shareApps: {
        const names = []
        for (const n of Pipewire.nodes.values) {
            const cls = n.properties?.["media.class"] ?? ""
            if (cls === "Stream/Input/Video") {
                const app = n.properties?.["application.name"] ?? n.properties?.["node.name"] ?? "an app"
                if (!names.includes(app)) names.push(app)
            }
        }
        return names
    }
    readonly property bool sharing: shareApps.length > 0
    readonly property bool recording: BarTools.recording
    readonly property bool mic: Audio.micBeingAccessed
    readonly property var chips: {
        const c = []
        if (recording) c.push({ icon: "fiber_manual_record", text: "Recording", sub: "Screen recorder", hot: true })
        if (obsRunning) c.push({ icon: "videocam", text: "OBS is open", sub: "OBS Studio", hot: false })
        if (sharing) c.push({ icon: "screen_share", text: "Sharing screen", sub: shareApps.join(", "), hot: true })
        if (mic) c.push({ icon: "mic", text: "Mic in use", sub: "", hot: true })
        return c
    }
    readonly property bool any: chips.length > 0
    readonly property bool hot: chips.some(c => c.hot)

    PwObjectTracker { objects: Pipewire.nodes.values }

    Process {
        id: obs
        command: ["pgrep", "-x", "obs"]
        onExited: code => root.obsRunning = code === 0
    }
    Timer { interval: 8000; repeat: true; running: true; triggeredOnStart: true; onTriggered: obs.running = true }
}
