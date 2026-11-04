import QtQuick
import qs
import qs.modules.common
import qs.services

// One capsule for the system status: cpu/memory, brightness, volume,
// network, battery and do-not-disturb. Each part opens its popup; scrolling
// over volume or brightness changes them.
BarPill {
    id: root

    property var parentScreen: null
    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

    component Divider: Rectangle { width: 1; height: 14; color: BarStyle.border }

    component Part: Item {
        id: part
        property string popup: ""
        property string icon: ""
        property string label: ""
        property string tip: ""
        property color tint: BarStyle.text
        property bool lit: false
        signal tapped()
        signal scrolled(var event)
        // 0..1 draws a progress arc around the icon (volume, brightness); -1 none.
        property real arc: -1
        property real arcShown: arc
        Behavior on arcShown { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        implicitWidth: partRow.implicitWidth + (arc >= 0 ? 6 : 0)
        implicitHeight: 24
        Canvas {
            visible: part.arc >= 0
            x: 0; y: Math.round((part.height - 24) / 2)
            width: 24; height: 24
            property real v: part.arcShown
            property color col: part.lit ? BarStyle.accent : BarStyle.text
            onVChanged: requestPaint()
            onColChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.reset()
                c.lineWidth = 2; c.lineCap = "round"
                c.strokeStyle = Qt.rgba(col.r, col.g, col.b, 0.22)
                c.beginPath(); c.arc(12, 12, 10, 0, 2 * Math.PI); c.stroke()
                c.strokeStyle = BarStyle.accent
                c.beginPath()
                c.arc(12, 12, 10, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.02, Math.min(1, v)))
                c.stroke()
            }
        }
        Row {
            id: partRow
            anchors.verticalCenter: parent.verticalCenter
            x: part.arc >= 0 ? 4 : 0
            spacing: 4
            BarIcon { name: part.icon; size: 16; color: part.lit ? BarStyle.accent : part.tint; fill: part.lit ? 1 : 0 }
            BarText { visible: part.label.length > 0; text: part.label }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -3
            cursorShape: Qt.PointingHandCursor
            onClicked: part.popup.length > 0 ? root.openPopup(part.popup) : part.tapped()
            onWheel: wheel => part.scrolled(wheel)
        }
        BarTip { text: part.tip }
    }

    Part {
        icon: "brightness_6"; tint: BarStyle.subtext
        tip: "Brightness " + Math.round(arc * 100) + "%"
        arc: Brightness.getMonitorForScreen(root.parentScreen)?.brightness ?? Brightness.monitors[0]?.brightness ?? 0
        popup: "brightness"
        onScrolled: event => event.angleDelta.y > 0 ? Brightness.increaseBrightness() : Brightness.decreaseBrightness()
    }
    Part {
        popup: "volume"
        tip: (Audio.sink?.audio?.muted ?? false) ? "Muted" : "Volume " + Math.round(Audio.value * 100) + "%"
        icon: (Audio.sink?.audio?.muted ?? false) || Audio.value <= 0 ? "volume_off" : "volume_up"
        arc: (Audio.sink?.audio?.muted ?? false) ? 0 : Math.min(1, Audio.value)
        onScrolled: event => event.angleDelta.y > 0 ? Audio.incrementVolume() : Audio.decrementVolume()
    }
    Divider {}
    Part {
        popup: "network"
        tip: NetLink.iwd ? (NetLink.ethUp ? "Ethernet" : NetLink.connected ? NetLink.ssid : "Not connected") : (Network.networkName.length > 0 ? Network.networkName : "Network")
        icon: NetLink.iwd ? NetLink.icon : Network.materialSymbol
        tint: (NetLink.iwd ? NetLink.connected || NetLink.ethUp : Network.ethernet || Network.wifiEnabled) ? BarStyle.text : BarStyle.subtext
    }
    Part {
        visible: BluetoothStatus.available && (Config.options?.bars?.top?.showBluetooth ?? true)
        popup: "network"
        tip: BluetoothStatus.connected ? BluetoothStatus.activeDeviceSummary() : (BluetoothStatus.enabled ? "Bluetooth" : "Bluetooth off")
        icon: !BluetoothStatus.enabled ? "bluetooth_disabled" : BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
        lit: BluetoothStatus.connected
        tint: BarStyle.subtext
    }
    Divider { visible: Battery.available && (Config.options?.bars?.top?.showBattery ?? true) }
    Part { visible: Battery.available && (Config.options?.bars?.top?.showBattery ?? true); popup: "battery"; tip: "Battery " + Math.round(Battery.percentage * 100) + "%" + (Battery.isCharging ? " charging" : ""); icon: Battery.isCharging ? "battery_charging_full" : "battery_full"; label: Math.round(Battery.percentage * 100) + "%"; tint: Battery.isCritical ? BarStyle.danger : BarStyle.text }
    Divider {}
    Part {
        popup: "notifications"
        tip: Notifications.count > 0 ? Notifications.count + " notifications" : "Notifications"
        icon: Notifications.silent ? "notifications_off" : "notifications"
        lit: Notifications.silent
        tint: BarStyle.subtext
        label: Notifications.count > 0 ? String(Notifications.count) : ""
    }
}
