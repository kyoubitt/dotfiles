import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services as Svc
import "../"
import "../reusables"

// The system monitor: uptime and load, four ring gauges (CPU, memory, GPU, disk), sixty-second graphs for the CPU and
// the network, one bar per core, the temperature and the busiest processes. Usage only, no battery (that is its own
// popup). It only polls while it is open.
Item {
    id: root
    visible: false

    property real intro: 0
    property var exitCallback: null
    // the host sizes the popup to this
    readonly property real contentHeight: col.implicitHeight + 28

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
    property var cores: []
    property real cpuTotal: 0
    property real mhz: 0
    property real memUsed: 0         // GB
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real rxSpeed: 0         // bytes per second
    property real txSpeed: 0
    property real diskUsedPct: 0
    property real diskFreeGb: 0
    property string gpuKind: ""      // "AMD", "NV" or ""
    property bool gpuIdle: false
    property real gpuLoad: 0         // 0..1
    property real vramUsed: 0        // GB
    property real vramTotal: 0
    property real uptimeSec: 0
    property string load: ""
    property var procsCpu: []
    property var procsMem: []
    property string sortBy: "cpu"
    readonly property var procs: sortBy === "cpu" ? procsCpu : procsMem
    property var cpuHist: []
    property var rxHist: []
    property var txHist: []
    readonly property int histLen: 60

    property var _prevCpu: ({})
    property double _prevRx: 0
    property double _prevTx: 0
    property double _prevT: 0

    function fmtSpeed(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s";
        if (b >= 1024) return Math.round(b / 1024) + " KB/s";
        return Math.round(b) + " B/s";
    }
    function fmtUptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d > 0 ? d + "d " : "") + h + "h " + m + "m";
    }
    function push(arr, v) {
        const a = arr.slice(-(histLen - 1));
        a.push(v);
        return a;
    }
    function parseProcs(block) {
        const list = [];
        for (const line of block.trim().split("\n")) {
            const f = line.trim().split(/\s+/);
            if (f.length < 3) continue;
            const mp = Number(f[f.length - 1]), cp = Number(f[f.length - 2]);
            if (isNaN(mp) || isNaN(cp)) continue;
            list.push({ name: f.slice(0, f.length - 2).join(" "), cpu: cp, mem: mp });
        }
        return list.slice(0, 6);
    }

    function parse(text) {
        const parts = text.split("---\n");
        // 0: cpu lines
        const loads = [];
        const prev = root._prevCpu, next = {};
        for (const line of parts[0].trim().split("\n")) {
            const f = line.trim().split(/\s+/);
            if (!f[0].startsWith("cpu")) continue;
            const v = f.slice(1).map(Number);
            const idle = v[3] + (v[4] || 0);
            const total = v.reduce((a, b) => a + b, 0);
            next[f[0]] = { idle: idle, total: total };
            const p = prev[f[0]];
            const load = p && total > p.total ? 1 - (idle - p.idle) / (total - p.total) : 0;
            if (f[0] === "cpu") root.cpuTotal = Math.max(0, Math.min(1, load));
            else loads.push(Math.max(0, Math.min(1, load)));
        }
        root._prevCpu = next;
        root.cores = loads;
        root.cpuHist = root.push(root.cpuHist, root.cpuTotal);
        // 1: memory
        const mem = {};
        for (const line of (parts[1] ?? "").trim().split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m) mem[m[1]] = Number(m[2]) / 1048576;
        }
        root.memTotal = mem.MemTotal ?? 0;
        root.memUsed = (mem.MemTotal ?? 0) - (mem.MemAvailable ?? 0);
        root.swapTotal = mem.SwapTotal ?? 0;
        root.swapUsed = (mem.SwapTotal ?? 0) - (mem.SwapFree ?? 0);
        // 2: network
        const net = (parts[2] ?? "").trim().split(/\s+/).map(Number);
        const now = Date.now();
        if (root._prevT > 0 && net.length >= 2 && !isNaN(net[0])) {
            const dt = (now - root._prevT) / 1000;
            if (dt > 0) {
                root.rxSpeed = Math.max(0, (net[0] - root._prevRx) / dt);
                root.txSpeed = Math.max(0, (net[1] - root._prevTx) / dt);
                root.rxHist = root.push(root.rxHist, root.rxSpeed);
                root.txHist = root.push(root.txHist, root.txSpeed);
            }
        }
        root._prevT = now; root._prevRx = net[0] || 0; root._prevTx = net[1] || 0;
        // 3: processes by cpu, 4: processes by memory
        root.procsCpu = root.parseProcs(parts[3] ?? "");
        root.procsMem = root.parseProcs(parts[4] ?? "");
        // 5: uptime and load average
        const up = (parts[5] ?? "").trim().split(/\s+/);
        root.uptimeSec = Number(up[0]) || 0;
        root.load = up.length >= 4 ? up[2] + "  " + up[3] + "  " + up[4] : "";
        // 6: average clock
        root.mhz = Number((parts[6] ?? "").trim()) || 0;
        // 7: gpu: "AMD busy vramUsedBytes vramTotalBytes" or "NV idle" or "NV load vramUsedMiB vramTotalMiB"
        let kind = "", idle = false, gload = 0, vu = 0, vt = 0;
        for (const line of (parts[7] ?? "").trim().split("\n")) {
            const f = line.trim().split(/\s+/);
            if (f[0] === "AMD" && Number(f[2]) >= 0) {
                kind = "AMD"; idle = false; gload = (Number(f[1]) || 0) / 100; vu = (Number(f[2]) || 0) / 1073741824; vt = (Number(f[3]) || 0) / 1073741824;
            } else if (f[0] === "NV" && kind === "") {
                kind = "NV";
                if (f[1] === "idle") { idle = true; } else { idle = false; gload = (Number(f[1]) || 0) / 100; vu = (Number(f[2]) || 0) / 1024; vt = (Number(f[3]) || 0) / 1024; }
            }
        }
        root.gpuKind = kind; root.gpuIdle = idle; root.gpuLoad = gload; root.vramUsed = vu; root.vramTotal = vt;
        // 8: disk (df)
        const df = (parts[8] ?? "").trim().split(/\s+/);
        if (df.length >= 5) {
            root.diskUsedPct = (parseFloat(df[4]) || 0) / 100;
            root.diskFreeGb = (Number(df[3]) || 0) / 1048576;
        }
    }

    Process {
        id: sampler
        command: ["sh", "-c",
            "grep '^cpu' /proc/stat; echo '---'; " +
            "grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo; echo '---'; " +
            "awk 'NR>2 && $1 !~ /^lo:/ {rx+=$2; tx+=$10} END {print rx+0, tx+0}' /proc/net/dev; echo '---'; " +
            "ps -eo comm=,pcpu=,pmem= --sort=-pcpu | head -6; echo '---'; " +
            "ps -eo comm=,pcpu=,pmem= --sort=-pmem | head -6; echo '---'; " +
            "cat /proc/uptime /proc/loadavg | tr '\\n' ' '; echo; echo '---'; " +
            "awk '/^cpu MHz/ {s+=$4; n++} END {if (n) printf \"%d\\n\", s/n}' /proc/cpuinfo; echo '---'; " +
            // the iGPU always answers; the dGPU only while it is awake, so asking never wakes it
            "for c in /sys/class/drm/card?; do d=$c/device; v=$(cat $d/vendor 2>/dev/null); " +
            "case $v in 0x1002) echo \"AMD $(cat $d/gpu_busy_percent 2>/dev/null) $(cat $d/mem_info_vram_used 2>/dev/null) $(cat $d/mem_info_vram_total 2>/dev/null)\";; " +
            "0x10de) if [ \"$(cat $d/power/runtime_status 2>/dev/null)\" = active ] && command -v nvidia-smi >/dev/null; then " +
            "echo \"NV $(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ',')\"; else echo 'NV idle'; fi;; esac; done; echo '---'; " +
            "df -P / | tail -1"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    Timer {
        id: poll
        interval: 1000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: if (!sampler.running) sampler.running = true
    }

    // ---- pieces
    component Ring: Item {
        id: ring
        property real value: 0
        property string text: ""
        property string caption: ""
        property string sub: ""
        property bool idle: false
        property color tone: ThemeBackend.blue
        readonly property real hot: idle ? 0 : value
        property real shown: hot
        Behavior on shown { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        implicitWidth: 100
        implicitHeight: 134
        onShownChanged: cv.requestPaint()
        onToneChanged: cv.requestPaint()
        Canvas {
            id: cv
            x: 4; y: 0
            width: 92; height: 92
            antialiasing: true
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.lineWidth = 8;
                c.lineCap = "round";
                c.strokeStyle = ThemeBackend.surface2.toString();
                c.beginPath();
                c.arc(46, 46, 40, 0, Math.PI * 2);
                c.stroke();
                if (ring.shown > 0.004) {
                    c.strokeStyle = (ring.shown >= 0.85 ? ThemeBackend.red : ring.tone).toString();
                    c.beginPath();
                    c.arc(46, 46, 40, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, ring.shown));
                    c.stroke();
                }
            }
            Component.onCompleted: requestPaint()
        }
        Text {
            renderType: Text.NativeRendering
            x: 4; y: 0; width: 92; height: 92
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: ring.text
            font.family: ThemeBackend.fontFamily
            font.pixelSize: ring.text.length > 5 ? 15 : 20
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
            color: ring.idle ? ThemeBackend.subtext0 : ThemeBackend.text
        }
        Text {
            renderType: Text.NativeRendering
            y: 98; width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: ring.caption
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: ThemeBackend.text
        }
        Text {
            renderType: Text.NativeRendering
            y: 116; width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: ring.sub
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 12
            font.features: { "tnum": 1 }
            color: ThemeBackend.subtext0
        }
    }

    // sixty bars, newest on the right; a second series is drawn as a thin line of caps over it
    component Graph: Item {
        id: g
        property var values: []
        property var overlay: []
        property real ceiling: 1
        property color tone: ThemeBackend.blue
        implicitHeight: 54
        readonly property real step: width / root.histLen
        Rectangle { anchors.fill: parent; radius: 8; color: ThemeBackend.surface1 }
        Repeater {
            model: root.histLen
            delegate: Item {
                required property int index
                readonly property int at: g.values.length - root.histLen + index
                readonly property real v: at >= 0 && at < g.values.length ? Math.min(1, g.values[at] / g.ceiling) : 0
                readonly property real o: at >= 0 && at < g.overlay.length ? Math.min(1, g.overlay[at] / g.ceiling) : 0
                x: index * g.step
                width: g.step
                height: g.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(1, parent.width - 1.5)
                    height: Math.max(v > 0 ? 2 : 0, (parent.height - 4) * parent.v)
                    radius: 1
                    color: parent.v >= 0.85 && g.ceiling === 1 ? ThemeBackend.red : g.tone
                }
                Rectangle {
                    visible: parent.o > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(1, parent.width - 1.5)
                    height: 2
                    y: parent.height - 2 - (parent.height - 6) * parent.o
                    color: ThemeBackend.text
                    opacity: 0.7
                }
            }
        }
    }

    component Section: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 28
        radius: ThemeBackend.borderRadius - 4
        color: ThemeBackend.surface0
        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
        }
    }

    component Label: Text {
        renderType: Text.NativeRendering
        font.family: ThemeBackend.fontFamily
        font.pixelSize: 13
        color: ThemeBackend.subtext0
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.base
        opacity: root.intro
        scale: 0.96 + 0.04 * root.intro
        transformOrigin: Item.TopRight
        clip: true

        GlassSheen {}

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            // header
            RowLayout {
                Layout.fillWidth: true
                Text {
                    renderType: Text.NativeRendering
                    text: "System monitor"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    color: ThemeBackend.text
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: "up " + root.fmtUptime(root.uptimeSec) + (root.load !== "" ? "   load " + root.load : "")
                    font.features: { "tnum": 1 }
                }
            }

            // four rings
            Section {
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    Ring {
                        value: root.cpuTotal
                        text: Math.round(root.cpuTotal * 100) + "%"
                        caption: "CPU"
                        sub: root.mhz > 0 ? (root.mhz / 1000).toFixed(2) + " GHz" : ""
                    }
                    Item { Layout.fillWidth: true }
                    Ring {
                        value: root.memTotal > 0 ? root.memUsed / root.memTotal : 0
                        text: Math.round(root.memTotal > 0 ? root.memUsed / root.memTotal * 100 : 0) + "%"
                        caption: "Memory"
                        sub: root.memUsed.toFixed(1) + " / " + root.memTotal.toFixed(1) + " GB"
                    }
                    Item { Layout.fillWidth: true }
                    Ring {
                        idle: root.gpuKind === "" || root.gpuIdle
                        value: root.gpuLoad
                        text: root.gpuKind === "" ? "n/a" : (root.gpuIdle ? "idle" : Math.round(root.gpuLoad * 100) + "%")
                        caption: "GPU"
                        sub: root.vramTotal > 0 ? root.vramUsed.toFixed(1) + " / " + root.vramTotal.toFixed(1) + " GB" : (root.gpuIdle ? "asleep" : "")
                    }
                    Item { Layout.fillWidth: true }
                    Ring {
                        value: root.diskUsedPct
                        text: Math.round(root.diskUsedPct * 100) + "%"
                        caption: "Disk"
                        sub: root.diskFreeGb.toFixed(0) + " GB free"
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            // graphs
            Section {
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "CPU, last minute" }
                            Item { Layout.fillWidth: true }
                            Label {
                                visible: Svc.ResourceUsage.cpuTemp > 0
                                text: Math.round(Svc.ResourceUsage.cpuTemp) + "°C"
                                font.features: { "tnum": 1 }
                                color: Svc.ResourceUsage.cpuTemp >= 85 ? ThemeBackend.red : ThemeBackend.subtext0
                            }
                        }
                        Graph { Layout.fillWidth: true; values: root.cpuHist; ceiling: 1 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Network" }
                            Item { Layout.fillWidth: true }
                            Label { text: "down " + root.fmtSpeed(root.rxSpeed) + "  up " + root.fmtSpeed(root.txSpeed); font.features: { "tnum": 1 }; font.pixelSize: 12 }
                        }
                        Graph {
                            Layout.fillWidth: true
                            values: root.rxHist
                            overlay: root.txHist
                            ceiling: Math.max(65536, Math.max.apply(null, root.rxHist.concat(root.txHist)))
                        }
                    }
                }
            }

            // per-core bars
            Section {
                Label { text: "Cores" + (root.swapTotal > 0 ? "" : "") }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    readonly property int n: Math.max(1, root.cores.length)
                    readonly property real gap: 4
                    readonly property real bw: Math.max(4, (width - (n - 1) * gap) / n)
                    Repeater {
                        model: root.cores
                        delegate: Item {
                            required property int index
                            required property real modelData
                            x: index * (parent.bw + parent.gap)
                            width: parent.bw
                            height: parent.height
                            Rectangle { anchors.fill: parent; radius: Math.min(4, width / 2); color: ThemeBackend.surface2 }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(width, parent.height * modelData)
                                radius: Math.min(4, width / 2)
                                color: modelData >= 0.85 ? ThemeBackend.red : ThemeBackend.blue
                                Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
                RowLayout {
                    visible: root.swapTotal > 0
                    Layout.fillWidth: true
                    Label { text: "Swap" }
                    Item { Layout.fillWidth: true }
                    Label { text: root.swapUsed.toFixed(1) + " / " + root.swapTotal.toFixed(1) + " GB"; font.features: { "tnum": 1 }; color: ThemeBackend.text }
                }
            }

            // processes
            Section {
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Busiest processes" }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: [{ k: "cpu", t: "CPU" }, { k: "mem", t: "Memory" }]
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: chipText.implicitWidth + 20
                            implicitHeight: 26
                            radius: 13
                            color: root.sortBy === modelData.k ? ThemeBackend.blue : ThemeBackend.surface1
                            Text {
                                id: chipText
                                renderType: Text.NativeRendering
                                anchors.centerIn: parent
                                text: modelData.t
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: root.sortBy === modelData.k ? ThemeBackend.crust : ThemeBackend.text
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { Sounds.playSfx("reusables/toggle/sfx.wav", 0.5); root.sortBy = modelData.k }
                            }
                        }
                    }
                }
                Repeater {
                    model: root.procs
                    delegate: RowLayout {
                        id: prow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        spacing: 10
                        readonly property string icon: Quickshell.iconPath(modelData.name.toLowerCase(), true)
                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            Image {
                                anchors.fill: parent
                                visible: status === Image.Ready
                                source: prow.icon !== "" ? (prow.icon.startsWith("/") ? "file://" + prow.icon : prow.icon) : ""
                                sourceSize: Qt.size(40, 40)
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                renderType: Text.NativeRendering
                                anchors.centerIn: parent
                                visible: prow.icon === ""
                                text: "terminal"
                                font.family: ThemeBackend.symbolFont
                                font.variableAxes: ({ "wght": 600, "opsz": 20 })
                                font.pixelSize: 18
                                color: ThemeBackend.subtext0
                            }
                        }
                        Text {
                            renderType: Text.NativeRendering
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.name
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 13
                            color: ThemeBackend.text
                        }
                        Rectangle {
                            Layout.preferredWidth: 72
                            Layout.preferredHeight: 5
                            radius: 2.5
                            color: ThemeBackend.surface2
                            Rectangle {
                                height: parent.height; radius: 2.5
                                width: parent.width * Math.min(1, (root.sortBy === "cpu" ? modelData.cpu : modelData.mem) / (root.sortBy === "cpu" ? 100 : 40))
                                color: (root.sortBy === "cpu" && modelData.cpu >= 50) ? ThemeBackend.red : ThemeBackend.blue
                            }
                        }
                        Text {
                            renderType: Text.NativeRendering
                            Layout.preferredWidth: 50
                            horizontalAlignment: Text.AlignRight
                            text: modelData.cpu.toFixed(1) + "%"
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: root.sortBy === "cpu" ? Font.DemiBold : Font.Normal; font.features: { "tnum": 1 }
                            color: root.sortBy === "cpu" ? ThemeBackend.text : ThemeBackend.subtext0
                        }
                        Text {
                            renderType: Text.NativeRendering
                            Layout.preferredWidth: 50
                            horizontalAlignment: Text.AlignRight
                            text: modelData.mem.toFixed(1) + "%"
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: root.sortBy === "mem" ? Font.DemiBold : Font.Normal; font.features: { "tnum": 1 }
                            color: root.sortBy === "mem" ? ThemeBackend.text : ThemeBackend.subtext0
                        }
                    }
                }
            }
        }
    }

    // TEMP DEBUG
    onCoresChanged: console.log("SYSMONDBG cores", cores.length, "cpu", Math.round(cpuTotal * 100), "mem", memUsed.toFixed(1), "/", memTotal.toFixed(1), "gpu", gpuKind, gpuIdle ? "idle" : Math.round(gpuLoad * 100), "up", Math.round(uptimeSec), "procs", procsCpu.length)
}
