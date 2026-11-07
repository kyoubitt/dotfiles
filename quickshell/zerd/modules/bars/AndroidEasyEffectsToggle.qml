import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

AndroidQuickToggleButton {
    id: root

    toggleModel: QuickToggleModel {
        name: Translation.tr("EasyEffects")
        available: EasyEffects.available
        toggled: EasyEffects.active
        icon: "graphic_eq"
        Component.onCompleted: EasyEffects.fetchActiveState()
        mainAction: () => EasyEffects.toggle()
        altAction: () => {
            Quickshell.execDetached(["bash", "-c", "flatpak run com.github.wwmm.easyeffects || easyeffects"])
            BarState.closeAll()
        }
        tooltipText: Translation.tr("EasyEffects | Right-click to configure")
    }
}
