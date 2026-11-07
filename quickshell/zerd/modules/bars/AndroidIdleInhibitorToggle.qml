import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

AndroidQuickToggleButton {
    id: root

    toggleModel: QuickToggleModel {
        name: Translation.tr("Keep awake")
        statusText: toggled ? Translation.tr("Staying awake") : Translation.tr("Off")
        toggled: BarTools.caffeine
        icon: "coffee"
        mainAction: () => BarTools.toggleCaffeine()
        tooltipText: Translation.tr("Keep system awake")
    }
}
