import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
    property var cores: []           // per-core load 0..1
    property real cpuTotal: 0
    property real memUsed: 0         // GB
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real rxSpeed: 0         // bytes per second
    property real txSpeed: 0
    property var procs: []
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
            if (name === "cpu") root.cpuTotal = Math.max(0, Math.min(1, load));
            else loads.push(Math.max(0, Math.min(1, load)));
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
        // processes
        const list = [];
        for (const line of (parts[3] ?? "").trim().split("\n")) {
            const f = line.trim().split(/\s+/);
            if (f.length < 3) continue;
            const mp = Number(f[f.length - 1]), cp = Number(f[f.length - 2]);
            if (isNaN(mp) || isNaN(cp)) continue;
            list.push({ name: f.slice(0, f.length - 2).join(" "), cpu: cp, mem: mp });
        }
        root.procs = list.slice(0, 5);
    }

    Process {
        id: sampler
        command: ["sh", "-c", "grep '^cpu' /proc/stat; echo '---'; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo; echo '---'; awk 'NR>2 && $1 !~ /^lo:/ {rx+=$2; tx+=$10} END {print rx+0, tx+0}' /proc/net/dev; echo '---'; ps -eo comm=,pcpu=,pmem= --sort=-pcpu | head -5"]
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

    // ---- look: three rings, a history chart, one bar per core, the busiest processes
    readonly property color cardColor: ThemeBackend.liquidGlass ? ThemeBackend.card : Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 1)
    readonly property color tile: Qt.tint(ThemeBackend.base, Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.07))
    readonly property real gpuLoad: -1

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: root.cardColor
        border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.08)
        opacity: root.intro
    }

    component Gauge: Item {
        id: g
        property string label
        property real fraction: 0
        property string caption
        property string glyph
        readonly property bool hot: fraction >= 0.85
        Layout.fillWidth: true
        Layout.preferredHeight: 128
        Rectangle { anchors.fill: parent; radius: 16; color: root.tile }
        Item {
            id: ring
            width: 78; height: 78
            anchors.horizontalCenter: parent.horizontalCenter
            y: 12
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.alpha(ThemeBackend.text, 0.12); strokeWidth: 7; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 39; centerY: 39; radiusX: 34; radiusY: 34; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: g.hot ? ThemeBackend.red : ThemeBackend.blue; strokeWidth: 7; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 39; centerY: 39; radiusX: 34; radiusY: 34; startAngle: -90
                        sweepAngle: 360 * Math.max(0.015, Math.min(1, g.fraction))
                        Behavior on sweepAngle { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: -1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: g.glyph
                    font.family: "Material Symbols Rounded"; font.variableAxes: ({ "wght": 600, "opsz": 20, "FILL": 1 }); font.pixelSize: 15
                    color: g.hot ? ThemeBackend.red : ThemeBackend.subtext0; renderType: Text.NativeRendering
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(g.fraction * 100) + "%"
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 17; font.weight: Font.Black; font.features: { "tnum": 1 }
                    color: g.hot ? ThemeBackend.red : ThemeBackend.text; renderType: Text.NativeRendering
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 94
            text: g.label
            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
            color: ThemeBackend.text; renderType: Text.NativeRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 111
            text: g.caption
            font.family: ThemeBackend.fontFamily; font.pixelSize: 12
            color: ThemeBackend.subtext0; renderType: Text.NativeRendering
        }
    }

    ColumnLayout {
        id: col
        x: 14; y: 14
        width: parent.width - 28
        spacing: 12
        opacity: root.intro

        // header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "System"
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily; font.pixelSize: 20; font.weight: Font.Black
                renderType: Text.NativeRendering
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredHeight: 26; Layout.preferredWidth: tempRow.implicitWidth + 20; radius: 13
                color: root.tile
                Row {
                    id: tempRow
                    anchors.centerIn: parent; spacing: 5
                    Text { text: "thermostat"; font.family: "Material Symbols Rounded"; font.variableAxes: ({ "wght": 600, "opsz": 20 }); font.pixelSize: 15; color: ThemeBackend.blue; renderType: Text.NativeRendering }
                    Text { text: Math.round(Svc.ResourceUsage.cpuTemp) + "\u00B0C"; font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 }; color: ThemeBackend.text; renderType: Text.NativeRendering }
                }
            }
        }

        // rings
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Gauge { label: "CPU"; glyph: "memory"; fraction: root.cpuTotal; caption: root.cores.length + " cores" }
            Gauge { label: "Memory"; glyph: "developer_board"; fraction: root.memTotal > 0 ? root.memUsed / root.memTotal : 0; caption: root.memUsed.toFixed(1) + " / " + root.memTotal.toFixed(1) + " GB" }
            Gauge { label: root.gpuLoad >= 0 ? "GPU" : "Disk"; glyph: root.gpuLoad >= 0 ? "videogame_asset" : "hard_drive"; fraction: root.gpuLoad >= 0 ? root.gpuLoad : Svc.ResourceUsage.diskUsedPercentage; caption: root.gpuLoad >= 0 ? "graphics" : "root disk" }
        }

        // history: CPU and memory over the last minute
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            radius: 16
            color: root.tile
            clip: true
            Canvas {
                id: chart
                anchors { fill: parent; margins: 12 }
                renderTarget: Canvas.FramebufferObject
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const draw = (arr, col, fill) => {
                        const n = arr.length;
                        if (n < 2) return;
                        const step = width / Math.max(1, n - 1);
                        ctx.beginPath();
                        ctx.moveTo(0, height);
                        for (let i = 0; i < n; i++) ctx.lineTo(i * step, height - Math.max(0, Math.min(1, arr[i])) * (height - 4) - 2);
                        ctx.lineTo(width, height);
                        ctx.closePath();
                        ctx.fillStyle = fill; ctx.fill();
                        ctx.beginPath();
                        for (let i = 0; i < n; i++) {
                            const y = height - Math.max(0, Math.min(1, arr[i])) * (height - 4) - 2;
                            if (i === 0) ctx.moveTo(0, y); else ctx.lineTo(i * step, y);
                        }
                        ctx.lineWidth = 2; ctx.strokeStyle = col; ctx.stroke();
                    };
                    const b = ThemeBackend.blue, t = ThemeBackend.subtext0;
                    draw(Svc.ResourceUsage.memoryUsageHistory, Qt.rgba(t.r, t.g, t.b, 0.8), Qt.rgba(t.r, t.g, t.b, 0.10));
                    draw(Svc.ResourceUsage.cpuUsageHistory, Qt.rgba(b.r, b.g, b.b, 1), Qt.rgba(b.r, b.g, b.b, 0.22));
                }
                Connections { target: Svc.ResourceUsage; function onCpuUsageHistoryChanged() { chart.requestPaint() } }
            }
            Row {
                anchors { right: parent.right; top: parent.top; margins: 10 }
                spacing: 12
                Row { spacing: 5; Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: ThemeBackend.blue } Text { text: "CPU"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext0; renderType: Text.NativeRendering } }
                Row { spacing: 5; Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: ThemeBackend.subtext0 } Text { text: "Memory"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext0; renderType: Text.NativeRendering } }
            }
        }

        // one bar per core
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 86
            radius: 16
            color: root.tile
            Text {
                x: 14; y: 10
                text: "Cores"
                font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 0.6; font.capitalization: Font.AllUppercase
                color: ThemeBackend.subtext0; renderType: Text.NativeRendering
            }
            Row {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
                height: 46
                spacing: 6
                Repeater {
                    model: root.cores
                    delegate: Item {
                        required property real modelData
                        width: (parent.width - 6 * (root.cores.length - 1)) / Math.max(1, root.cores.length); height: parent.height
                        Rectangle { anchors.fill: parent; radius: 5; color: Qt.alpha(ThemeBackend.text, 0.10) }
                        Rectangle {
                            anchors.bottom: parent.bottom; width: parent.width; radius: 5
                            height: Math.max(4, parent.height * modelData)
                            color: modelData >= 0.85 ? ThemeBackend.red : ThemeBackend.blue
                            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }

        // the busiest processes
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: procCol.implicitHeight + 28
            radius: 16
            color: root.tile
            Column {
                id: procCol
                x: 14; y: 12
                width: parent.width - 28
                spacing: 8
                Text {
                    text: "Busiest"
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 0.6; font.capitalization: Font.AllUppercase
                    color: ThemeBackend.subtext0; renderType: Text.NativeRendering
                }
                Repeater {
                    model: root.procs
                    delegate: Item {
                        required property var modelData
                        width: procCol.width; height: 26
                        Rectangle {
                            height: parent.height; radius: 8
                            width: Math.max(8, parent.width * Math.min(1, modelData.cpu / 100))
                            color: Qt.alpha(ThemeBackend.blue, 0.20)
                        }
                        Text {
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 190
                            text: modelData.name
                            elide: Text.ElideRight
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Medium
                            color: ThemeBackend.text; renderType: Text.NativeRendering
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: 92; verticalCenter: parent.verticalCenter }
                            text: modelData.cpu.toFixed(1) + "%"
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; font.features: { "tnum": 1 }
                            color: ThemeBackend.text; renderType: Text.NativeRendering
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: modelData.mem.toFixed(1) + "% mem"
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.features: { "tnum": 1 }
                            color: ThemeBackend.subtext0; renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
    }
}
