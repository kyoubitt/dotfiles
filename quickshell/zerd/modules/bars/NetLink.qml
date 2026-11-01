pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Network state for machines that use iwd instead of NetworkManager. `iwd` is
// false when NetworkManager runs; the bar then keeps using the nmcli service.
Singleton {
    id: root

    property bool iwd: false
    property string device: ""
    property bool wifiEnabled: true
    property bool connected: false
    property bool scanning: false
    property string ssid: ""
    property string ip: ""
    property string band: ""
    property string security: ""
    property int strength: 0
    property int rssi: -100
    // Link rate in Mb/s as reported by iwd, and a plain word for the signal.
    property int linkMbps: 0
    readonly property string quality: root.rssi >= -55 ? "Excellent" : root.rssi >= -65 ? "Good" : root.rssi >= -75 ? "Fair" : "Weak"
    property var networks: []
    property var known: ({})
    property string ethDevice: ""
    property bool ethUp: false
    property string ethIp: ""
    property int ethSpeed: 0

    readonly property string icon: root.ethUp ? "lan"
        : !root.wifiEnabled ? "signal_wifi_off"
        : !root.connected ? "wifi_find"
        : root.strength > 75 ? "signal_wifi_4_bar" : root.strength > 50 ? "network_wifi_3_bar"
        : root.strength > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar"

    function refresh(): void { if (!snapshot.running) snapshot.running = true }
    function scan(): void {
        if (!root.device) return
        root.scanning = true
        scanProc.command = ["iwctl", "station", root.device, "scan"]
        scanProc.running = true
    }
    function connectTo(name: string, passphrase: string): void {
        if (!root.device) return
        actProc.command = passphrase.length > 0
            ? ["iwctl", "--passphrase", passphrase, "station", root.device, "connect", name]
            : ["iwctl", "station", root.device, "connect", name]
        actProc.running = true
    }
    function disconnectNow(): void {
        if (root.device) { actProc.command = ["iwctl", "station", root.device, "disconnect"]; actProc.running = true }
    }
    function forget(name: string): void {
        actProc.command = ["iwctl", "known-networks", name, "forget"]
        actProc.running = true
    }
    function setPowered(on: bool): void {
        if (root.device) { actProc.command = ["iwctl", "device", root.device, "set-property", "Powered", on ? "on" : "off"]; actProc.running = true }
    }

    Component.onCompleted: detect.running = true

    Process {
        id: detect
        command: ["sh", "-c", "systemctl is-active --quiet NetworkManager && echo nm || (systemctl is-active --quiet iwd && echo iwd || echo none)"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.iwd = text.trim() === "iwd"
                if (root.iwd) { root.refresh(); monitor.running = true }
            }
        }
    }
    // Link and address changes trigger a refresh; a slow timer covers signal drift.
    Process {
        id: monitor
        command: ["ip", "monitor", "link", "address"]
        stdout: SplitParser { onRead: refreshDebounce.restart() }
        onRunningChanged: if (!running && root.iwd) restart.start()
    }
    Timer { id: restart; interval: 3000; onTriggered: monitor.running = true }
    Timer { id: refreshDebounce; interval: 600; onTriggered: root.refresh() }
    Timer { interval: 20000; repeat: true; running: root.iwd; onTriggered: root.refresh() }

    Process { id: scanProc; onRunningChanged: if (!running) { root.scanning = false; refreshDebounce.restart() } }
    Process { id: actProc; onRunningChanged: if (!running) refreshDebounce.restart() }

    Process {
        id: snapshot
        command: ["sh", Quickshell.shellPath("modules/bars/netlink.sh")]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function parse(out: string): void {
        const sections = {}
        let cur = "head"
        sections[cur] = []
        for (const line of out.split("\n")) {
            const m = /^---(\w+)/.exec(line)
            if (m) { cur = m[1]; sections[cur] = []; continue }
            sections[cur].push(line)
        }
        const dev = (sections.head.find(l => l.startsWith("WL|")) ?? "WL|").slice(3).trim()
        root.device = dev

        const props = {}
        for (const l of sections.SHOW ?? []) {
            const m = /^\s+(\S.*?)\s{2,}(\S.*?)\s*$/.exec(l)
            if (m && !props[m[1]]) props[m[1]] = m[2]
        }
        root.connected = props["State"] === "connected"
        root.scanning = props["Scanning"] === "yes"
        root.ssid = props["Connected network"] ?? ""
        root.ip = props["IPv4 address"] ?? ""
        const f = parseInt(props["Frequency"] ?? "0")
        root.band = f > 4000 ? "5 GHz" : f > 2000 ? "2.4 GHz" : ""
        root.security = props["Security"] ?? ""
        const rssi = parseInt(props["RSSI"] ?? "-100")
        root.strength = Math.max(0, Math.min(100, 2 * (rssi + 100)))
        root.rssi = rssi
        const tx = parseInt(props["TxBitrate"] ?? "0"), rx = parseInt(props["RxBitrate"] ?? "0")
        root.linkMbps = Math.round(Math.max(tx, rx) / 1000)
        root.wifiEnabled = (sections.POWER?.[0] ?? "on").trim() !== "off"

        const nets = []
        for (const l of sections.NETS ?? []) {
            const m = /^\s*(>)?\s*(\S.*?)\s{2,}(psk|open|8021x|wep)\s+(\*+)/.exec(l)
            if (m) nets.push({ ssid: m[2], secure: m[3] !== "open", enterprise: m[3] === "8021x", strength: m[4].length * 25, active: m[1] === ">" })
        }
        root.networks = nets

        const known = {}
        for (const l of sections.KNOWN ?? []) {
            const m = /^\s+(\S.*?)\s{2,}(psk|open|8021x|wep)\s/.exec(l)
            if (m && m[1] !== "Name") known[m[1]] = true
        }
        root.known = known

        let ethUp = false, ethDev = "", ethIp = "", ethSpeed = 0
        for (const l of sections.ETH ?? []) {
            const p = l.split("|")
            if (p.length < 4) continue
            if (!ethDev || p[1].trim() === "1") {
                ethDev = p[0]; ethUp = p[1].trim() === "1"
                ethIp = p[3].trim(); ethSpeed = Math.max(0, parseInt(p[2]) || 0)
            }
        }
        root.ethDevice = ethDev; root.ethUp = ethUp; root.ethIp = ethIp; root.ethSpeed = ethSpeed
    }
}
