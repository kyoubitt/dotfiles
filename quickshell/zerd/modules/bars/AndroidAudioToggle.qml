import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

AndroidQuickToggleButton {
    id: root

    toggleModel: QuickToggleModel {
        name: Translation.tr("Audio output")
        statusText: toggled ? Math.round(Audio.value * 100) + "%" : Translation.tr("Muted")
        tooltipText: Translation.tr("Audio output | Right-click for volume mixer & device selector")
        toggled: !(Audio.sink?.audio?.muted ?? false)
        icon: toggled ? "volume_up" : "volume_off"
        mainAction: () => Audio.toggleMute()
        hasMenu: true
    }
}
