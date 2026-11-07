import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

AndroidQuickToggleButton {
    id: root

    toggleModel: QuickToggleModel {
        name: Translation.tr("Focus")
        statusText: toggled ? Translation.tr("On") : Translation.tr("Off")
        toggled: BarTools.focusMode
        icon: "self_improvement"
        mainAction: () => BarTools.toggleFocusMode()
        tooltipText: Translation.tr("Focus mode: do not disturb, caffeine and night light")
    }
}
