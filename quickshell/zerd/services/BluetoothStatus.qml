pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

/**
 * Bluetooth status service.
 */
Singleton {
    id: root

    readonly property bool available: Bluetooth.adapters.values.length > 0
    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property BluetoothDevice firstActiveDevice: Bluetooth.defaultAdapter?.devices.values.find(device => device.connected) ?? null
    readonly property int activeDeviceCount: Bluetooth.defaultAdapter?.devices.values.filter(device => device.connected).length ?? 0
    readonly property bool connected: Bluetooth.devices.values.some(d => d.connected)

    // Connected devices first, then paired ones, then the rest found while scanning.
    readonly property list<var> friendlyDeviceList: {
        const all = Bluetooth.defaultAdapter?.devices.values ?? []
        const connected = all.filter(d => d.connected)
        const paired = all.filter(d => !d.connected && (d.paired || d.bonded))
        const other = all.filter(d => !d.connected && !(d.paired || d.bonded))
        return [...connected, ...paired, ...other]
    }

    // For the vendored iRiS controls card: name of the connected device, or a count.
    function activeDeviceSummary(): string {
        if (!enabled) return ""
        if (activeDeviceCount === 0) return ""
        return activeDeviceCount === 1 ? (firstActiveDevice?.name ?? "") : `${activeDeviceCount} devices`
    }
}
