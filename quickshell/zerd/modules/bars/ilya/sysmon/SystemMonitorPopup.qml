import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services as Svc
import "../"

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

    component Meter: ColumnLayout {
        id: m
        property string label
        property string value
        property real fraction: 0
        property color tone: ThemeBackend.blue
        Layout.fillWidth: true
        spacing: 5
        RowLayout {
            Layout.fillWidth: true
            Text { renderType: Text.NativeRendering; text: m.label; font.family: ThemeBackend.fontFamily; font.pixelSize: 13; color: ThemeBackend.subtext0 }
            Item { Layout.fillWidth: true }
            Text { renderType: Text.NativeRendering; text: m.value; font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 }; color: ThemeBackend.text }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            radius: 3
            color: ThemeBackend.surface2
            Rectangle {
                height: parent.height; radius: 3
                width: parent.width * Math.max(0, Math.min(1, m.fraction))
                color: m.fraction >= 0.85 ? ThemeBackend.red : m.tone
                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            }
        }
    }

    component Section: Rectangle {
        default property alias content: inner.data
        property string title: ""
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

    Rectangle {
        id: card
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.base
        opacity: root.intro
        scale: 0.96 + 0.04 * root.intro
        transformOrigin: Item.TopRight
        clip: true

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            Text {
                renderType: Text.NativeRendering
                text: "System monitor"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: ThemeBackend.text
            }

            // CPU
            Section {
                RowLayout {
                    Layout.fillWidth: true
                    Text { renderType: Text.NativeRendering; text: "CPU"; font.family: ThemeBackend.fontFamily; font.pixelSize: 13; color: ThemeBackend.subtext0 }
                    Item { Layout.fillWidth: true }
                    Text {
                        renderType: Text.NativeRendering
                        visible: Svc.ResourceUsage.cpuTemp > 0
                        text: Math.round(Svc.ResourceUsage.cpuTemp) + "°C"
                        font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.features: { "tnum": 1 }
                        color: Svc.ResourceUsage.cpuTemp >= 85 ? ThemeBackend.red : ThemeBackend.subtext0
                    }
                    Text {
                        renderType: Text.NativeRendering
                        Layout.leftMargin: 12
                        text: Math.round(root.cpuTotal * 100) + "%"
                        font.family: ThemeBackend.fontFamily; font.pixelSize: 22; font.weight: Font.Bold; font.features: { "tnum": 1 }
                        color: root.cpuTotal >= 0.85 ? ThemeBackend.red : ThemeBackend.text
                    }
                }
                // one bar per core
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
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
            }

            // memory
            Section {
                Meter {
                    label: "Memory"
                    value: root.memUsed.toFixed(1) + " / " + root.memTotal.toFixed(1) + " GB"
                    fraction: root.memTotal > 0 ? root.memUsed / root.memTotal : 0
                }
                Meter {
                    visible: root.swapTotal > 0
                    label: "Swap"
                    value: root.swapUsed.toFixed(1) + " / " + root.swapTotal.toFixed(1) + " GB"
                    fraction: root.swapTotal > 0 ? root.swapUsed / root.swapTotal : 0
                }
            }

            // GPU, disk, network
            Section {
                Meter {
                    visible: Svc.ResourceUsage.gpuAvailable
                    label: "GPU"
                    value: Math.round(Svc.ResourceUsage.gpuUsage * 100) + "%"
                    fraction: Svc.ResourceUsage.gpuUsage
                }
                Meter {
                    label: "Disk (/)"
                    value: Math.round(Svc.ResourceUsage.diskUsedPercentage * 100) + "%"
                    fraction: Svc.ResourceUsage.diskUsedPercentage
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { renderType: Text.NativeRendering; text: "Network"; font.family: ThemeBackend.fontFamily; font.pixelSize: 13; color: ThemeBackend.subtext0 }
                    Item { Layout.fillWidth: true }
                    Text {
                        renderType: Text.NativeRendering
                        text: "down " + root.fmtSpeed(root.rxSpeed) + "    up " + root.fmtSpeed(root.txSpeed)
                        font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
                        color: ThemeBackend.text
                    }
                }
            }

            // processes
            Section {
                Text { renderType: Text.NativeRendering; text: "Busiest processes"; font.family: ThemeBackend.fontFamily; font.pixelSize: 13; color: ThemeBackend.subtext0 }
                Repeater {
                    model: root.procs
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        spacing: 8
                        Text {
                            renderType: Text.NativeRendering
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.name
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 13
                            color: ThemeBackend.text
                        }
                        Text {
                            renderType: Text.NativeRendering
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            text: modelData.cpu.toFixed(1) + "%"
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
                            color: modelData.cpu >= 50 ? ThemeBackend.red : ThemeBackend.text
                        }
                        Text {
                            renderType: Text.NativeRendering
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            text: modelData.mem.toFixed(1) + "%"
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.features: { "tnum": 1 }
                            color: ThemeBackend.subtext0
                        }
                    }
                }
            }
        }
    }

    // TEMP DEBUG
    onCoresChanged: console.log("SYSMONDBG cores", cores.length, "cpu", Math.round(cpuTotal * 100), "mem", memUsed.toFixed(1), "/", memTotal.toFixed(1), "procs", procs.length)
}
