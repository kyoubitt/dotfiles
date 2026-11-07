import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Bluetooth

AndroidQuickToggleButton {
    id: root

    toggleModel: QuickToggleModel {
        name: Translation.tr("Bluetooth")
        statusText: BluetoothStatus.enabled ? (BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("Not connected")) : Translation.tr("Off")
        tooltipText: Translation.tr("%1 | Right-click to configure").arg(
            (BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("Bluetooth"))
            + (BluetoothStatus.activeDeviceCount > 1 ? ` +${BluetoothStatus.activeDeviceCount - 1}` : "")
        )
        icon: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
        available: BluetoothStatus.available
        toggled: BluetoothStatus.enabled
        mainAction: () => {
            const a = Bluetooth.defaultAdapter
            if (a) a.enabled = !a.enabled
        }
        hasMenu: true
    }
}
