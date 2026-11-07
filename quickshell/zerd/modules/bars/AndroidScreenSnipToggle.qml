import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

AndroidQuickToggleButton {
    id: root

    toggleModel: QuickToggleModel {
        name: Translation.tr("Screen snip")
        hasStatusText: false
        toggled: false
        icon: "screenshot_region"
        mainAction: () => {
            BarState.closeAll()
            snipDelay.start()
        }
        tooltipText: Translation.tr("Screen snip")
        property Timer snipDelay: Timer {
            interval: 300
            onTriggered: Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "screenshot", "region"])
        }
    }
}
