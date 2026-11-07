import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

AndroidQuickToggleButton {
    id: root

    toggleModel: QuickToggleModel {
        name: Translation.tr("Audio input")
        statusText: toggled ? Translation.tr("Enabled") : Translation.tr("Muted")
        toggled: !(Audio.source?.audio?.muted ?? false)
        icon: toggled ? "mic" : "mic_off"
        mainAction: () => Audio.toggleMicMute()
        hasMenu: true
        tooltipText: Translation.tr("Audio input | Right-click for volume mixer & device selector")
    }
}
