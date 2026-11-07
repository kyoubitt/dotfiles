import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

AndroidQuickToggleButton {
    id: root

    toggleModel: QuickToggleModel {
        name: Translation.tr("Night Light")
        statusText: toggled ? Translation.tr("Active") : Translation.tr("Inactive")
        toggled: BarTools.nightLight
        icon: "bedtime"
        mainAction: () => BarTools.toggleNightLight()
        hasMenu: true
        tooltipText: Translation.tr("Night Light | Right-click to configure")
    }
}
