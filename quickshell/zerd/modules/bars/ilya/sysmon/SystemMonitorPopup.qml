import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.services as Svc
import "../"
import "../reusables"

// The system monitor: CPU with one bar per core and the temperature, memory and swap, GPU, disk, network speed
// and the five busiest processes. It only polls while it is open.
Item {
    id: root
    visible: false

    property real intro: 0
    property var exitCallback: null
    // the host sizes the popup to this
    readonly property real contentHeight: col.implicitHeight + 36

    function startExit(onFinished) { exitCallback = onFinished; introAnim.stop(); outAnim.restart(); }
    function resetAndPlayIntro() { outAnim.stop(); intro = 0; introAnim.restart(); }
    onVisibleChanged: {
        if (visible) {
            Svc.ResourceUsage.keepAlive();
            resetAndPlayIntro();
            poll.restart();
        } else {
            Svc.ResourceUsage.releaseKeepAlive();
            introAnim.stop(); outAnim.stop(); intro = 0;
        }
    }
    NumberAnimation { id: introAnim; target: root; property: "intro"; to: 1; duration: 240; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: outAnim
        NumberAnimation { target: root; property: "intro"; to: 0; duration: 160; easing.type: Easing.InCubic }
        ScriptAction { script: { if (root.exitCallback) { const cb = root.exitCallback; root.exitCallback = null; cb(); } } }
    }

    // ---- data
    property var cores: []           // per-core load 0..1
    readonly property real cpuTotal: Svc.ResourceUsage.cpuUsage
    property real memUsed: 0         // GB
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real rxSpeed: 0         // bytes per second
    property real txSpeed: 0
    property real uptime: 0          // seconds
    property var _prevCpu: ({})
    property double _prevNet: 0
    property double _prevRx: 0
    property double _prevTx: 0
    property double _prevT: 0

    function fmtSpeed(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s";
        if (b >= 1024) return Math.round(b / 1024) + " KB/s";
        return Math.round(b) + " B/s";
    }

    function parse(text) {
        const parts = text.split("---");
        // cpu lines
        const cpu = parts[0].trim().split("\n");
        const loads = [];
        const prev = root._prevCpu;
        const next = {};
        for (const line of cpu) {
            const f = line.trim().split(/\s+/);
            const name = f[0];
            if (!name.startsWith("cpu")) continue;
            const v = f.slice(1).map(Number);
            const idle = v[3] + (v[4] || 0);
            const total = v.reduce((a, b) => a + b, 0);
            next[name] = { idle: idle, total: total };
            const p = prev[name];
            const load = p && total > p.total ? 1 - (idle - p.idle) / (total - p.total) : 0;
            if (name !== "cpu") loads.push(Math.max(0, Math.min(1, load)));
        }
        root._prevCpu = next;
        root.cores = loads;
        // memory
        const mem = {};
        for (const line of (parts[1] ?? "").trim().split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m) mem[m[1]] = Number(m[2]) / 1048576;
        }
        root.memTotal = mem.MemTotal ?? 0;
        root.memUsed = (mem.MemTotal ?? 0) - (mem.MemAvailable ?? 0);
        root.swapTotal = mem.SwapTotal ?? 0;
        root.swapUsed = (mem.SwapTotal ?? 0) - (mem.SwapFree ?? 0);
        // network
        const net = (parts[2] ?? "").trim().split(/\s+/).map(Number);
        const now = Date.now();
        if (root._prevT > 0 && net.length >= 2 && !isNaN(net[0])) {
            const dt = (now - root._prevT) / 1000;
            if (dt > 0) {
                root.rxSpeed = Math.max(0, (net[0] - root._prevRx) / dt);
                root.txSpeed = Math.max(0, (net[1] - root._prevTx) / dt);
            }
        }
        root._prevT = now; root._prevRx = net[0] || 0; root._prevTx = net[1] || 0;
        root.uptime = Number((parts[3] ?? "0").trim()) || 0;
    }

    Process {
        id: sampler
        command: ["sh", "-c", "grep '^cpu' /proc/stat; echo '---'; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo; echo '---'; awk 'NR>2 && $1 !~ /^lo:/ {rx+=$2; tx+=$10} END {print rx+0, tx+0}' /proc/net/dev; echo '---'; cut -d' ' -f1 /proc/uptime"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    Timer {
        id: poll
        interval: 2000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: if (!sampler.running) sampler.running = true
    }

    // ---- look: the power menu's capsules for the four loads, one line of facts, the busiest processes in plain rows
    readonly property real gpuLoad: Svc.ResourceUsage.gpuAvailable ? Svc.ResourceUsage.gpuUsage : -1
    readonly property real memFrac: memTotal > 0 ? memUsed / memTotal : 0
    property real shownCpu: 0
    Behavior on shownCpu { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    onCpuTotalChanged: shownCpu = cpuTotal
    Component.onCompleted: shownCpu = cpuTotal
    readonly property color tone: ThemeBackend.blue
    function hotTone(f) { return f >= 0.9 ? ThemeBackend.red : tone }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.card
        clip: true
        opacity: root.intro
        GlassSheen {}
        WallpaperBlur {
            z: -1
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
        }
    }

    ColumnLayout {
        id: col
        x: 18; y: 18
        width: parent.width - 36
        spacing: 14
        opacity: root.intro

        Row {
            id: caps
            Layout.fillWidth: true
            spacing: 12
            readonly property real w: (width - 36) / 4
            PopupCapsule { width: caps.w; height: 168; icon: "memory"; value: Math.round(root.shownCpu * 100) + "%"; caption: "CPU"; level: root.shownCpu; tone: root.hotTone(root.cpuTotal) }
            PopupCapsule { width: caps.w; height: 168; icon: "developer_board"; value: Math.round(root.memFrac * 100) + "%"; caption: root.memUsed.toFixed(1) + " GB"; level: root.memFrac; tone: root.hotTone(root.memFrac) }
            PopupCapsule { width: caps.w; height: 168; icon: "videogame_asset"; value: root.gpuLoad >= 0 ? Math.round(root.gpuLoad * 100) + "%" : "–"; caption: "GPU"; level: Math.max(0, root.gpuLoad); tone: root.tone }
            PopupCapsule { width: caps.w; height: 168; icon: "hard_drive"; value: Math.round(Svc.ResourceUsage.diskUsedPercentage * 100) + "%"; caption: "Disk"; level: Svc.ResourceUsage.diskUsedPercentage; tone: root.tone }
        }

        Text {
            Layout.leftMargin: 4
            Layout.fillWidth: true
            text: Math.round(Svc.ResourceUsage.cpuTemp) + "\u00B0C  \u00B7  " + root.cores.length + " cores  \u00B7  " + root.memUsed.toFixed(1) + " / " + root.memTotal.toFixed(1) + " GB memory"
            color: ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Medium
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        // network and uptime, set plain under the capsules
        Row {
            id: facts
            Layout.fillWidth: true
            Layout.topMargin: 2
            readonly property real w: width / 3
            function up(sec) {
                const d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600), m = Math.floor((sec % 3600) / 60);
                return d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m");
            }
            Repeater {
                model: [
                    { i: "arrow_downward", v: root.fmtSpeed(root.rxSpeed), k: "Download" },
                    { i: "arrow_upward", v: root.fmtSpeed(root.txSpeed), k: "Upload" },
                    { i: "schedule", v: facts.up(root.uptime), k: "Uptime" }
                ]
                delegate: Item {
                    required property var modelData
                    width: facts.w; height: 56
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.i
                            font.family: "Material Symbols Rounded"; font.variableAxes: ({ "wght": 600, "opsz": 24 })
                            font.pixelSize: 22; color: root.tone
                            renderType: Text.NativeRendering
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: modelData.v
                                color: ThemeBackend.text
                                font.family: ThemeBackend.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; font.features: { "tnum": 1 }
                                renderType: Text.NativeRendering
                            }
                            Text {
                                text: modelData.k
                                color: ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily; font.pixelSize: 12
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }
            }
        }
    }
}
