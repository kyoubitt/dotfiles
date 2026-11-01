pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Orbit's own player: Spotify's headless client "Soloist" runs as a small background process and shows up as a
// Spotify Connect device called "Orbit". The shell talks to it over a local WebSocket (scripts/music/wsbridge.py),
// so playback needs no Spotify app, no Web API polling, and almost no memory.
Singleton {
    id: root

    readonly property bool wanted: (Config.options?.music?.engine ?? "app") === "soloist"
    readonly property string dir: Quickshell.env("HOME") + "/.local/share/zerd-soloist"
    property bool installed: false
    property bool hasKey: false
    property bool connected: false          // the websocket is up
    property bool loggedIn: false           // the device has been paired with the account
    property string note: ""

    // ---- what is playing, in the shape the Web API uses, so the rest of the window does not care where it came from
    property string status: "idle"
    property var item: null
    property var contextEntity: null
    property real posMs: 0
    property real posAt: 0
    property real speed: 0
    property int volume: 60
    property bool shuffle: false
    property string repeat: "off"
    property var shape: null
    property var upcoming: []               // the next songs, for looking their lyrics up early
    function rebuild(): void {
        const it = root.item
        const dec = it?.decorations
        const covers = dec?.visual_identity?.cover ?? []
        const big = covers.find(c => c.size === "xlarge") ?? covers.find(c => c.size === "large") ?? covers[covers.length - 1]
        const uri = it?.uri ?? ""
        root.shape = it ? {
            is_playing: root.status === "playing" || root.status === "buffering",
            progress_ms: root.posMs + (root.speed > 0 ? (Date.now() - root.posAt) * root.speed : 0),
            shuffle_state: root.shuffle, repeat_state: root.repeat,
            context: root.contextEntity?.uri ? { uri: root.contextEntity.uri } : null,
            device: { name: "Orbit", volume_percent: root.volume },
            item: {
                id: uri.split(":")[2] ?? "", uri: uri, type: it.entity_type ?? "track", name: dec?.identity?.name ?? "",
                duration_ms: dec?.playback?.duration_ms ?? 0,
                artists: (dec?.creators ?? []).map(c => { const e = c?.entity ?? c; return { name: e?.decorations?.identity?.name ?? "", id: (e?.uri ?? "").split(":")[2] ?? "", uri: e?.uri ?? "" } }),
                album: { name: dec?.parent?.entity?.decorations?.identity?.name ?? "", id: (dec?.parent?.entity?.uri ?? "").split(":")[2] ?? "", images: covers.length > 0 ? [{ url: big?.url ?? "" }] : [] }
            }
        } : null
    }

    // a Soloist item in the shape the Web API uses for tracks
    function asTrack(i: var): var {
        const d = i?.decorations; const covers = d?.visual_identity?.cover ?? []
        return { uri: i?.uri ?? "", id: (i?.uri ?? "").split(":")[2] ?? "", name: d?.identity?.name ?? "", duration_ms: d?.playback?.duration_ms ?? 0,
            artists: (d?.creators ?? []).map(c => ({ name: (c?.entity ?? c)?.decorations?.identity?.name ?? "" })),
            album: { name: d?.parent?.entity?.decorations?.identity?.name ?? "", images: covers.length > 0 ? [{ url: covers[covers.length - 1].url }] : [] } }
    }

    Process { running: true; command: ["sh", "-c", "command -v soloist >/dev/null && echo y"]; stdout: StdioCollector { onStreamFinished: root.installed = text.trim() === "y" } }
    Process { running: true; command: ["sh", "-c", "test -s \"$HOME/.config/soloist/api-key\" && echo y"]; stdout: StdioCollector { onStreamFinished: root.hasKey = text.trim() === "y" } }

    Connections { target: MusicStore; function onActiveChanged() { if (MusicStore.active && root.wanted) root.start() } }
    // the checks for the binary and the key finish a moment after startup: start then if the window is already open
    onInstalledChanged: { if (root.wanted && MusicStore.active) root.start(); else root.attachIfRunning() }
    onHasKeyChanged: { if (root.wanted && MusicStore.active) root.start(); else root.attachIfRunning() }
    onWantedChanged: { if (root.wanted && MusicStore.active) root.start(); else root.attachIfRunning() }

    // A Soloist that is already running (it outlives a shell reload) is picked up at once, so the bar follows what plays
    // even when the Orbit window has not been opened.
    Process {
        id: attach
        command: ["sh", "-c", "pgrep -x soloist >/dev/null && echo y"]
        stdout: StdioCollector { onStreamFinished: if (text.trim() === "y" && root.wanted) root.start() }
    }
    function attachIfRunning(): void { if (root.wanted && root.installed && root.hasKey && !daemon.running) attach.running = true }

    // ---- the daemon
    Process {
        id: daemon
        stderr: SplitParser { onRead: line => { if (/expired/i.test(line)) root.note = "The Soloist build has expired: download a newer one" } }
        onExited: code => { root.connected = false; root.loggedIn = false; if (code === 10) root.note = "The Soloist build has expired: download a newer one" }
    }
    Process {
        id: bridge
        stdinEnabled: true
        stdout: SplitParser { onRead: line => root.onMessage(line) }
        onRunningChanged: if (!running) { root.connected = false; root.loggedIn = false }
    }
    function start(): void {
        if (!root.installed || !root.hasKey) { root.note = !root.installed ? "Soloist is not installed" : "Soloist needs its API key in ~/.config/soloist/api-key"; return }
        if (daemon.running) return
        root.note = ""
        // a Soloist left over from before a shell reload keeps running: reuse it instead of fighting it for the data directory
        daemon.command = ["sh", "-c", "D=\"" + root.dir + "\"; mkdir -p \"$D\"; if pgrep -x soloist >/dev/null && [ -s \"$D/ws.port\" ]; then exec sleep 2147483647; fi; rm -f \"$D/ws.port\"; exec soloist -n Orbit -k \"$(cat \"$HOME/.config/soloist/api-key\")\" -D \"$D\" --ws 127.0.0.1:0 -i 60"]
        daemon.running = true
        bridgeStart.restart()
    }
    function stop(): void { bridge.running = false; daemon.running = false; Quickshell.execDetached(["pkill", "-x", "soloist"]) }
    Timer { id: bridgeStart; interval: 1200
        onTriggered: { bridge.command = ["python3", "-I", Quickshell.shellPath("scripts/music/wsbridge.py"), root.dir + "/ws.port"]; bridge.running = true } }

    function send(obj: var): void { if (bridge.running) bridge.write(JSON.stringify(Object.assign({ type: "command" }, obj)) + "\n") }

    function onMessage(line: string): void {
        let m; try { m = JSON.parse(line) } catch (e) { return }
        root.connected = true
        switch (m.type) {
        case "auth_state":
            root.loggedIn = m.logged_in === true
            if (root.loggedIn) root.note = ""
            else root.note = "Pick \"Orbit\" in the Spotify app's device list once to connect it"
            break
        case "playback_state":
            root.status = m.status ?? "idle"; root.item = m.item ?? null; root.contextEntity = m.context ?? null
            root.volume = m.volume ?? root.volume
            root.shuffle = m.options?.shuffle ?? false; root.repeat = m.options?.repeat ?? "off"
            root.anchor(m.position); root.rebuild(); break
        case "track_changed": root.item = m.item ?? null; root.rebuild(); root.send({ command: "get_queue", limit: 5 }); break
        case "queue_changed": root.upcoming = (m.upcoming ?? []).map(e => e.item).filter(i => i); break
        case "playback_changed": root.status = m.status ?? root.status; root.anchor(null); root.rebuild(); break
        case "context_changed": root.contextEntity = m.context ?? null; root.rebuild(); break
        case "volume_changed": root.volume = m.volume ?? root.volume; root.rebuild(); break
        case "options_changed": root.shuffle = m.options?.shuffle ?? root.shuffle; root.repeat = m.options?.repeat ?? root.repeat; root.rebuild(); break
        case "position_sync": root.anchor(m.position); root.rebuild(); break
        case "error": root.note = m.message ?? ""; break
        }
    }
    function anchor(p: var): void {
        if (p) { root.posMs = p.position_ms ?? 0; root.posAt = p.timestamp_ms ?? Date.now(); root.speed = p.speed ?? (root.status === "playing" ? 1 : 0) }
        else { root.posMs = root.shape?.progress_ms ?? root.posMs; root.posAt = Date.now(); root.speed = root.status === "playing" ? 1 : 0 }
    }

    // ---- control
    function ready(done: var): void {
        root.start()
        let tries = 0
        const poll = () => {
            if (root.loggedIn) { done(); return }
            if (!root.installed || !root.hasKey) { done(); return }
            if (++tries < 40) readyTimer.restart(); else done()
        }
        readyTimer.callback = poll
        poll()
    }
    Timer { id: readyTimer; interval: 400; property var callback: null; onTriggered: if (callback) callback() }
    function play(uri: string): void { root.send({ command: "activate" }); root.send({ command: "play", uri: uri }) }
    function playMany(uris: var): void {
        if (uris.length === 0) return
        root.send({ command: "activate" }); root.send({ command: "play", uri: uris[0] })
        queueTimer.rest = uris.slice(1, 40); queueTimer.restart()
    }
    Timer { id: queueTimer; interval: 1500; property var rest: []
        onTriggered: { for (const u of rest) root.send({ command: "add_to_queue", uri: u }); rest = [] } }
    function resume(): void { root.send({ command: "play" }) }
    function pause(): void { root.send({ command: "pause" }) }
    function next(): void { root.send({ command: "skip_next" }) }
    function previous(): void { root.send({ command: "skip_prev" }) }
    function seek(ms: real): void { root.send({ command: "seek", position_ms: Math.round(ms) }) }
    function setVolume(p: int): void { root.volume = p; root.send({ command: "set_volume", volume: p }) }
    function setShuffle(on: bool): void { root.send({ command: "set_shuffle", enabled: on }) }
    function setRepeat(mode: string): void {
        root.send({ command: "set_repeat_track", enabled: mode === "track" })
        root.send({ command: "set_repeat_context", enabled: mode === "context" })
    }
}
