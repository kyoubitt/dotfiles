import QtQuick
import qs.services

// Wi-Fi/ethernet and Bluetooth state as two glyphs.
BarPill {
    BarIcon {
        name: Network.materialSymbol
        color: Network.ethernet || Network.wifiEnabled ? BarStyle.text : BarStyle.subtext
    }
    BarIcon {
        visible: BluetoothStatus.available
        name: !BluetoothStatus.enabled ? "bluetooth_disabled" : BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
        color: BluetoothStatus.connected ? BarStyle.accent : BarStyle.subtext
    }
}
