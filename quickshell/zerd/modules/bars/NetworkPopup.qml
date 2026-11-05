import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.services

// Internet menu: Ethernet / Wi-Fi / Bluetooth tabs. Each shows a header card
// for what is connected (with an info view) and the list of what can be joined.
Column {
    id: root

    readonly property bool iwd: NetLink.iwd
    property string mode: (iwd ? NetLink.ethUp : Network.ethernet) && !(iwd ? NetLink.wifiEnabled && NetLink.connected : Network.wifiEnabled) ? "eth" : "wifi"
    property bool info: false
    property var links: ({})        // type -> { dev, state, ip, speed }
    property var saved: ({})        // connection name -> type
    property real down: 0
    property real up: 0
    property real _rx: -1
    property real _tx: -1

    // One shape for both backends: { ssid, secure, strength, active, band, ap }.
    readonly property var allNets: iwd
        ? NetLink.networks.map(n => ({ ssid: n.ssid, secure: n.secure, enterprise: n.enterprise, strength: n.strength, active: n.active, band: "", ap: null }))
        : Network.wifiNetworks.map(n => ({ ssid: n.ssid, secure: n.isSecure, enterprise: false, strength: n.strength, active: n.active, band: root.band(n.frequency), ap: n }))
    readonly property var nets: allNets.slice().sort((a, b) => (b.active - a.active) || (b.strength - a.strength)).slice(0, 7)
    readonly property bool wifiOn: iwd ? NetLink.wifiEnabled : Network.wifiEnabled
    readonly property bool wifiBusy: iwd ? NetLink.scanning : Network.wifiScanning
    readonly property bool online: iwd ? NetLink.connected : Network.active !== null
    readonly property string ssidNow: iwd ? NetLink.ssid : (Network.active?.ssid ?? "")
    readonly property int signalNow: iwd ? NetLink.strength : (Network.active?.strength ?? 0)
    readonly property string speedNow: iwd ? (NetLink.linkMbps > 0 ? NetLink.linkMbps + " Mb/s" : "") : ""
    readonly property string signalWord: iwd ? NetLink.quality + "  (" + NetLink.rssi + " dBm)" : signalNow + "%"
    readonly property string ipNow: iwd ? NetLink.ip : (links["wifi"]?.ip ?? "")
    readonly property string bandNow: iwd ? NetLink.band : band(Network.active?.frequency ?? 0)
    readonly property string securityNow: iwd ? NetLink.security : (Network.active?.security ?? "")
    readonly property bool wired: iwd ? NetLink.ethUp : Network.ethernet
    readonly property string wiredDev: iwd ? NetLink.ethDevice : (links["ethernet"]?.dev ?? "")
    readonly property string wiredIp: iwd ? NetLink.ethIp : (links["ethernet"]?.ip ?? "")
    readonly property string wiredSpeed: iwd ? (NetLink.ethSpeed > 0 ? String(NetLink.ethSpeed) : "") : (links["ethernet"]?.speed ?? "")
    property string askSsid: ""
    function isKnown(n: string): bool { return iwd ? !!NetLink.known[n] : !!saved[n] }
    function join(n: var): void {
        if (iwd) {
            if (n.secure && !n.enterprise && !isKnown(n.ssid)) askSsid = n.ssid
            else NetLink.connectTo(n.ssid, "")
        } else Network.connectToWifiNetwork(n.ap)
    }
    function forgetNet(n: string): void {
        if (iwd) NetLink.forget(n)
        else { Quickshell.execDetached(["nmcli", "connection", "delete", n]); saver.running = true }
    }
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btAll: (adapter?.devices?.values ?? []).slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))
    readonly property var btShown: btAll.filter(d => d.paired || d.connected || adapter?.discovering)
    readonly property var vpns: Object.keys(saved).filter(n => saved[n] === "vpn" || saved[n] === "wireguard")
    spacing: 12
    width: 320

    function rate(b: real): string {
        if (b < 1024) return Math.round(b) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(0) + " KB/s"
        return (b / 1048576).toFixed(1) + " MB/s"
    }
    function band(f: int): string { return f > 4000 ? "5 GHz" : f > 2000 ? "2.4 GHz" : "" }

    Component.onCompleted: {
        if (iwd) { NetLink.refresh(); NetLink.scan() }
        else { if (Network.wifiEnabled) Network.rescanWifi(); probe.running = true; saver.running = true }
    }
    onModeChanged: info = false

    Process {
        id: probe
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE dev | while IFS=: read d t s; do case $t in wifi|ethernet) echo \"$t|$d|$s|$(nmcli -g IP4.ADDRESS dev show \"$d\" | head -1)|$(nmcli -g CAPABILITIES.SPEED dev show \"$d\" | head -1)\";; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                for (const l of text.split("\n")) {
                    const p = l.split("|")
                    if (p.length >= 5) out[p[0]] = { dev: p[1], state: p[2], ip: p[3], speed: p[4] }
                }
                root.links = out
            }
        }
    }
    Process {
        id: saver
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                for (const l of text.split("\n")) {
                    const i = l.lastIndexOf(":")
                    if (i > 0) out[l.slice(0, i)] = l.slice(i + 1).replace("802-11-wireless", "wifi").replace("802-3-ethernet", "ethernet")
                }
                root.saved = out
            }
        }
    }
    Process {
        id: traffic
        command: ["cat", "/proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                let rx = 0, tx = 0
                for (const l of text.split("\n").slice(2)) {
                    const m = /^\s*([^:]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/.exec(l)
                    if (m && m[1] !== "lo") { rx += parseFloat(m[2]); tx += parseFloat(m[3]) }
                }
                if (root._rx >= 0) { root.down = rx - root._rx; root.up = tx - root._tx }
                root._rx = rx; root._tx = tx
            }
        }
    }
    Timer { interval: 1000; repeat: true; running: true; onTriggered: traffic.running = true }
    Timer { interval: 6000; repeat: true; running: !root.iwd; onTriggered: { probe.running = true; saver.running = true } }

    // the shared Material 3 switch, with the on / tapped names this popup uses
    component Switch: BarSwitch {
        property bool on: false
        signal tapped()
        checked: on
        onToggled: tapped()
    }
    component Tab: Rectangle {
        id: tab
        property string icon
        property string text
        property bool on: false
        signal tapped()
        width: (320 - 12) / 3; height: 34; radius: 17
        color: on ? BarStyle.accent : BarStyle.plateHover
        Behavior on color { ColorAnimation { duration: 110 } }
        Row {
            anchors.centerIn: parent; spacing: 6
            BarIcon { name: tab.icon; size: 16; color: tab.on ? BarStyle.onAccent : BarStyle.subtext }
            BarText { text: tab.text; font.pixelSize: 12; color: tab.on ? BarStyle.onAccent : BarStyle.text }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tab.tapped() }
    }
    // A connected-thing card: big icon, name, state, and an info view.
    component Core: Rectangle {
        id: core
        property string icon
        property string title
        property string sub
        property bool connected: false
        property var details: []
        width: 320; height: 64 + (root.info ? details.length * 22 + 10 : 0)
        radius: BarStyle.radiusMedium
        color: connected ? Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.16) : BarStyle.plateHover
        border.width: 1; border.color: connected ? BarStyle.accent : BarStyle.border
        clip: true
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Rectangle {
            x: 12; y: 12; width: 40; height: 40; radius: 20
            color: core.connected ? BarStyle.accent : BarStyle.plate
            BarIcon { anchors.centerIn: parent; name: core.icon; fill: 1; size: 20; color: core.connected ? BarStyle.onAccent : BarStyle.subtext }
        }
        Column {
            x: 62; y: 12; width: 200
            BarText { text: core.title; font.weight: Font.DemiBold; width: parent.width; elide: Text.ElideRight }
            BarText { text: core.sub; font.pixelSize: 11; color: BarStyle.subtext; width: parent.width; elide: Text.ElideRight }
        }
        BarIcon {
            visible: core.connected
            anchors.right: parent.right; anchors.rightMargin: 14; y: 22
            name: root.info ? "expand_less" : "info"; size: 18; color: BarStyle.subtext
            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: root.info = !root.info }
        }
        Column {
            x: 16; y: 64; spacing: 0
            opacity: root.info ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 110 } }
            Repeater {
                model: core.details
                delegate: Row {
                    required property var modelData
                    height: 22
                    BarText { width: 90; text: modelData[0]; font.pixelSize: 11; color: BarStyle.subtext }
                    BarText { width: 200; text: modelData[1]; font.pixelSize: 12; elide: Text.ElideRight }
                }
            }
        }
    }
    component Entry: Item {
        id: entry
        property string icon
        property string title
        property string sub
        property bool active: false
        property bool secure: false
        property string action: ""
        signal tapped()
        signal secondary()
        width: 320; height: 40
        BarHoverFill { anchors.fill: parent; hovered: ma.containsMouse; pressed: ma.pressed }
        BarIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: entry.icon; size: 18; color: entry.active ? BarStyle.accent : BarStyle.subtext }
        Column {
            x: 40; anchors.verticalCenter: parent.verticalCenter; width: 190
            BarText { text: entry.title; width: parent.width; elide: Text.ElideRight; font.weight: entry.active ? Font.DemiBold : Font.Medium }
            BarText { visible: entry.sub.length > 0; text: entry.sub; font.pixelSize: 11; color: BarStyle.subtext; width: parent.width; elide: Text.ElideRight }
        }
        BarIcon { visible: entry.secure; anchors.right: parent.right; anchors.rightMargin: 96; anchors.verticalCenter: parent.verticalCenter; name: "lock"; size: 13; color: BarStyle.subtext }
        BarText {
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            visible: ma.containsMouse || entry.active
            text: entry.action; font.pixelSize: 11; color: BarStyle.accent
        }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? entry.secondary() : entry.tapped()
        }
    }

    Row {
        spacing: 6
        Tab { icon: "lan"; text: "Wired"; on: root.mode === "eth"; onTapped: root.mode = "eth" }
        Tab { icon: "wifi"; text: "Wi-Fi"; on: root.mode === "wifi"; onTapped: root.mode = "wifi" }
        Tab { icon: "bluetooth"; text: "Bluetooth"; on: root.mode === "bt"; onTapped: root.mode = "bt"; visible: BluetoothStatus.available }
    }

    // ---- Wired
    Column {
        visible: root.mode === "eth"
        spacing: 10
        Core {
            icon: "lan"
            title: root.wired ? "Ethernet" : "No cable"
            sub: root.wired ? (root.wiredIp || "Connected") : (root.wiredDev ? root.wiredDev + "  ·  not plugged in" : "No wired adapter")
            connected: root.wired
            details: [["Device", root.wiredDev || "-"], ["Address", root.wiredIp || "-"], ["Link speed", root.wiredSpeed ? root.wiredSpeed + " Mb/s" : "-"]]
        }
    }

    // ---- Wi-Fi
    Column {
        visible: root.mode === "wifi"
        spacing: 10
        Row {
            spacing: 8
            BarText { width: 240; anchors.verticalCenter: parent.verticalCenter; text: root.wifiOn ? (root.wifiBusy ? "Scanning..." : "Wi-Fi on") : "Wi-Fi off"; color: BarStyle.subtext; font.pixelSize: 12 }
            BarIcon { visible: root.wifiOn; anchors.verticalCenter: parent.verticalCenter; name: "refresh"; size: 16; color: root.wifiBusy ? BarStyle.accent : BarStyle.subtext
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.iwd ? NetLink.scan() : Network.rescanWifi() } }
            Switch { anchors.verticalCenter: parent.verticalCenter; on: root.wifiOn; onTapped: root.iwd ? NetLink.setPowered(!NetLink.wifiEnabled) : Network.toggleWifi() }
        }
        Core {
            icon: root.iwd ? NetLink.icon : Network.materialSymbol
            title: root.online ? root.ssidNow : "Not connected"
            sub: root.online ? ("Connected" + (root.speedNow ? "  ·  " + root.speedNow : "  ·  " + root.signalNow + "%")) : "Pick a network below"
            connected: root.online
            details: [["Address", root.ipNow || "-"], ["Link speed", root.speedNow || "-"], ["Signal", root.signalWord], ["Band", root.bandNow || "-"], ["Security", root.securityNow || "Open"]]
        }
        Column {
            visible: root.wifiOn
            spacing: 2
            Repeater {
                model: root.nets.filter(n => !n.active)
                delegate: Column {
                    id: row
                    required property var modelData
                    Entry {
                        icon: modelData.strength > 75 ? "signal_wifi_4_bar" : modelData.strength > 50 ? "network_wifi_3_bar" : modelData.strength > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                        title: modelData.ssid
                        sub: [root.isKnown(modelData.ssid) ? "Saved" : "", modelData.enterprise ? "Enterprise" : "", modelData.band].filter(s => s).join("  ·  ")
                        secure: modelData.secure
                        action: "Connect"
                        onTapped: root.join(modelData)
                        onSecondary: if (root.isKnown(modelData.ssid)) root.forgetNet(modelData.ssid)
                    }
                    Rectangle {
                        id: pwRow
                        visible: root.iwd ? root.askSsid === modelData.ssid : (modelData.ap?.askingPassword ?? false)
                        width: 320; height: visible ? 48 : 0
                        radius: BarStyle.radiusSmall
                        color: BarStyle.plateHover
                        border.width: 1
                        border.color: pwInput.activeFocus ? BarStyle.accent : BarStyle.border
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                        property bool reveal: false
                        function submit(): void {
                            if (pwInput.text.length === 0) return
                            if (root.iwd) { NetLink.connectTo(row.modelData.ssid, pwInput.text); root.askSsid = "" }
                            else { Network.changePassword(row.modelData.ap, pwInput.text); Network.connectToWifiNetwork(row.modelData.ap) }
                            pwInput.text = ""
                        }
                        onVisibleChanged: if (visible) pwInput.forceActiveFocus()
                        BarIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "key"; size: 16; color: BarStyle.subtext }
                        BarText { x: 38; anchors.verticalCenter: parent.verticalCenter; visible: pwInput.text.length === 0; text: "Password for " + row.modelData.ssid; color: BarStyle.subtext; width: 170; elide: Text.ElideRight; font.pixelSize: 12 }
                        TextInput {
                            id: pwInput
                            x: 38; width: 170; height: parent.height
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: pwRow.reveal ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "•"
                            color: BarStyle.text
                            selectionColor: BarStyle.accent
                            selectedTextColor: BarStyle.onAccent
                            font.pixelSize: BarStyle.fontSize
                            clip: true
                            onAccepted: pwRow.submit()
                            Keys.onEscapePressed: root.askSsid = ""
                        }
                        Item {
                            x: 214; width: 28; height: parent.height
                            BarIcon { anchors.centerIn: parent; name: pwRow.reveal ? "visibility_off" : "visibility"; size: 16; color: BarStyle.subtext }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pwRow.reveal = !pwRow.reveal }
                        }
                        Rectangle {
                            x: 246; anchors.verticalCenter: parent.verticalCenter
                            width: 64; height: 32; radius: 16
                            color: pwInput.text.length > 0 ? BarStyle.accent : BarStyle.border
                            Behavior on color { ColorAnimation { duration: 100 } }
                            BarText { anchors.centerIn: parent; text: "Join"; font.pixelSize: 12; font.weight: Font.DemiBold; color: pwInput.text.length > 0 ? BarStyle.onAccent : BarStyle.subtext }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pwRow.submit() }
                        }
                    }
                }
            }
            Entry {
                visible: root.online
                icon: "link_off"; title: "Disconnect"; action: "Disconnect"
                onTapped: root.iwd ? NetLink.disconnectNow() : Network.disconnectWifiNetwork()
            }
        }
    }

    // ---- Bluetooth
    Column {
        visible: root.mode === "bt"
        spacing: 10
        Row {
            spacing: 8
            BarText { width: 240; anchors.verticalCenter: parent.verticalCenter; text: !BluetoothStatus.enabled ? "Bluetooth off" : root.adapter?.discovering ? "Searching..." : "Bluetooth on"; color: BarStyle.subtext; font.pixelSize: 12 }
            BarIcon { visible: BluetoothStatus.enabled; anchors.verticalCenter: parent.verticalCenter; name: root.adapter?.discovering ? "bluetooth_searching" : "search"; size: 16; color: root.adapter?.discovering ? BarStyle.accent : BarStyle.subtext
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.adapter) root.adapter.discovering = !root.adapter.discovering } } }
            Switch { anchors.verticalCenter: parent.verticalCenter; on: BluetoothStatus.enabled; onTapped: { if (root.adapter) root.adapter.enabled = !root.adapter.enabled } }
        }
        Core {
            icon: BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
            title: BluetoothStatus.activeDeviceSummary() || "Nothing connected"
            sub: BluetoothStatus.connected ? "Connected" : "Pick a device below"
            connected: BluetoothStatus.connected
            details: [["Device", BluetoothStatus.firstActiveDevice?.name ?? "-"], ["Battery", BluetoothStatus.firstActiveDevice?.batteryAvailable ? Math.round(BluetoothStatus.firstActiveDevice.battery * 100) + "%" : "-"], ["Address", BluetoothStatus.firstActiveDevice?.address ?? "-"]]
        }
        Column {
            visible: BluetoothStatus.enabled
            spacing: 2
            Repeater {
                model: root.btShown.filter(d => !d.connected)
                delegate: Entry {
                    required property var modelData
                    icon: "bluetooth"
                    title: modelData.name || modelData.address
                    sub: modelData.paired ? "Paired" : "New device"
                    action: modelData.paired ? "Connect" : "Pair"
                    onTapped: modelData.paired ? modelData.connect() : modelData.pair()
                }
            }
            Entry {
                visible: BluetoothStatus.connected
                icon: "bluetooth_disabled"; title: "Disconnect"; action: "Disconnect"
                onTapped: BluetoothStatus.firstActiveDevice?.disconnect()
            }
        }
    }

    // ---- Shared footer: live traffic and VPN
    Rectangle { width: 320; height: 1; color: BarStyle.border }
    Row {
        spacing: 18
        Row { spacing: 5; BarIcon { name: "arrow_downward"; size: 14; color: BarStyle.accent } BarText { text: root.rate(root.down); font.pixelSize: 12 } }
        Row { spacing: 5; BarIcon { name: "arrow_upward"; size: 14; color: BarStyle.subtext } BarText { text: root.rate(root.up); font.pixelSize: 12 } }
    }
    Column {
        visible: root.vpns.length > 0
        spacing: 2
        Repeater {
            model: root.vpns
            delegate: Entry {
                required property string modelData
                icon: "vpn_lock"; title: modelData; sub: "VPN"; action: "Toggle"
                onTapped: Quickshell.execDetached(["sh", "-c", "nmcli connection show --active | grep -q \"^$1 \" && nmcli connection down \"$1\" || nmcli connection up \"$1\"", "sh", modelData])
            }
        }
    }
}
