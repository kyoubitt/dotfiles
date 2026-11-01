pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// One shared cava process for every visualizer. Lean stand-in for iNiR's CavaService:
// consumers subscribe(bars) / unsubscribe(id); while anyone is subscribed one process
// runs and `points` carries the bars scaled to 0..100. The cava config is written to
// the cache folder; it reads the default PulseAudio/PipeWire source.
Singleton {
    id: root

    property var _requests: ({})
    property int _next: 1
    readonly property int _bars: {
        let n = 0
        for (const k in root._requests) n = Math.max(n, root._requests[k])
        return Math.max(12, Math.min(160, n || 48))
    }
    readonly property bool active: Object.keys(root._requests).length > 0

    property list<real> points: []
    readonly property real normalizationCeiling: 100
    property bool audioSignalActive: false

    readonly property string configPath: FileUtils.trimFileProtocol(Directories.cache) + "/cava_visualizer.txt"

    function subscribe(requestedBars): int {
        const id = root._next++
        const copy = Object.assign({}, root._requests)
        copy[id] = Number(requestedBars) || 48
        root._requests = copy
        return id
    }
    function updateSubscription(requestId: int, requestedBars): void {
        if (!(requestId in root._requests)) return
        const copy = Object.assign({}, root._requests)
        copy[requestId] = Number(requestedBars) || 48
        root._requests = copy
    }
    function unsubscribe(requestId): void {
        const copy = Object.assign({}, root._requests)
        delete copy[requestId]
        root._requests = copy
        if (Object.keys(copy).length === 0) { root.points = []; root.audioSignalActive = false }
    }

    // Write the config, then start cava. Restarts when the bar count changes.
    Process {
        id: writer
        onExited: if (root.active) cava.running = true
    }
    on_BarsChanged: if (root.active) { cava.running = false; root._start() }
    onActiveChanged: if (active) root._start(); else cava.running = false

    function _start(): void {
        const cfg = `[general]\nmode = normal\nframerate = 30\nautosens = 1\nbars = ${root._bars}\n\n[input]\nmethod = pulse\nsource = auto\n\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nchannels = mono\nmono_option = average\n\n[smoothing]\nnoise_reduction = 30\n`
        writer.command = ["sh", "-c", `printf '%s' "$1" > "$2"`, "sh", cfg, root.configPath]
        writer.running = true
    }

    Process {
        id: cava
        command: ["cava", "-p", root.configPath]
        stdout: SplitParser {
            onRead: data => {
                const values = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
                root.points = values
                root.audioSignalActive = values.some(v => v > 4)
            }
        }
    }
}
