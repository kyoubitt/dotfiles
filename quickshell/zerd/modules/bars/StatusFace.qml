import QtQuick
import qs
import qs.modules.common
import qs.services

// One capsule for the system status: brightness, volume, network, bluetooth, battery and do-not-disturb. Round
// buttons sharing a liquid hover; each opens its popup, scrolling over volume or brightness changes them.
BarPill {
    id: root
    strip: true

    property var parentScreen: null
    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

    component Divider: Item {
        width: 7; height: 14
        Rectangle { anchors.centerIn: parent; width: 1; height: 14; color: BarStyle.border }
    }

    component Part: BarCell {
        id: part
        property string popup: ""
        property string icon: ""
        property string label: ""
        property color tint: BarStyle.text
        property bool lit: false
        // 0..1 draws a ring around the icon (volume, brightness); -1 none.
        property real arc: -1
        property real arcShown: arc
        Behavior on arcShown { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        signal scrolled(var event)
        wheelEnabled: arc >= 0
        onWheel: event => part.scrolled(event)
        onTapped: if (popup.length > 0) root.openPopup(popup)
        fill: lit ? BarStyle.accentContainer : "transparent"
        padding: label.length > 0 ? 8 : 5

        Item {
            width: BarStyle.iconSize; height: BarStyle.iconSize
            anchors.verticalCenter: parent.verticalCenter
            BarArc {
                visible: part.arc >= 0
                anchors.centerIn: parent
                size: 26; lineWidth: 2
                value: part.arcShown
                color: BarStyle.accent
            }
            BarIcon { anchors.centerIn: parent; name: part.icon; color: part.lit ? BarStyle.onAccentContainer : part.tint; fill: part.lit ? 1 : 0 }
        }
        BarText { visible: part.label.length > 0; anchors.verticalCenter: parent.verticalCenter; text: part.label; font.weight: Font.DemiBold }
    }

    Part {
        icon: "brightness_6"; tint: BarStyle.subtext
        tip: "Brightness " + Math.round(arc * 100) + "%"
        arc: Brightness.getMonitorForScreen(root.parentScreen)?.brightness ?? Brightness.monitors[0]?.brightness ?? 0
        popup: "brightness"
        onScrolled: event => event.angleDelta.y > 0 ? Brightness.increaseBrightness() : Brightness.decreaseBrightness()
    }
    Part {
        visible: Config.options?.bars?.top?.showVolume ?? true
        popup: "volume"
        tip: (Audio.sink?.audio?.muted ?? false) ? "Muted" : "Volume " + Math.round(Audio.value * 100) + "%"
        icon: (Audio.sink?.audio?.muted ?? false) || Audio.value <= 0 ? "volume_off" : "volume_up"
        arc: (Audio.sink?.audio?.muted ?? false) ? 0 : Math.min(1, Audio.value)
        onScrolled: event => event.angleDelta.y > 0 ? Audio.incrementVolume() : Audio.decrementVolume()
    }
    Divider {}
    Part {
        visible: Config.options?.bars?.top?.showNetwork ?? true
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
    Part {
        visible: Battery.available && (Config.options?.bars?.top?.showBattery ?? true)
        popup: "battery"
        tip: "Battery " + Math.round(Battery.percentage * 100) + "%" + (Battery.isCharging ? " charging" : "")
        icon: Battery.isCharging ? "battery_charging_full" : "battery_full"
        label: Math.round(Battery.percentage * 100) + "%"
        tint: Battery.isCritical ? BarStyle.danger : BarStyle.text
    }
    Divider {}
    Part {
        visible: Config.options?.bars?.top?.showBell ?? true
        popup: "notifications"
        tip: Notifications.count > 0 ? Notifications.count + " notifications" : "Notifications"
        icon: Notifications.silent ? "notifications_off" : "notifications"
        lit: Notifications.silent
        tint: BarStyle.subtext
        label: Notifications.count > 0 ? String(Notifications.count) : ""
    }
}
