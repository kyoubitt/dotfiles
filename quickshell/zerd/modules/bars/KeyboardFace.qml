import QtQuick
import Quickshell
import qs.services

// Active keyboard layout; click cycles to the next one. Hidden with a single layout.
BarPill {
    id: root

    visible: (NiriService.keyboardLayoutNames?.length ?? 0) > 1
    interactive: true
    tip: "Keyboard layout"
    onClicked: Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])

    BarIcon { name: "keyboard"; color: BarStyle.subtext }
    BarText { text: String(NiriService.getCurrentKeyboardLayoutName() ?? "").slice(0, 2).toUpperCase(); font.weight: Font.DemiBold }
}
