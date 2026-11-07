import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

AndroidQuickToggleButton {
    id: root

    toggleModel: QuickToggleModel {
        name: Translation.tr("Internet")
        statusText: NetLink.iwd ? (NetLink.connected ? NetLink.ssid : (NetLink.wifiEnabled ? Translation.tr("Not connected") : Translation.tr("Off"))) : Network.networkName
        tooltipText: Translation.tr("%1 | Right-click to configure").arg(NetLink.iwd ? NetLink.ssid : Network.networkName)
        icon: NetLink.iwd ? NetLink.icon : Network.materialSymbol
        toggled: NetLink.iwd ? NetLink.wifiEnabled : Network.wifiStatus !== "disabled"
        mainAction: () => { if (NetLink.iwd) NetLink.setPowered(!NetLink.wifiEnabled); else Network.toggleWifi() }
        hasMenu: true
    }
}
