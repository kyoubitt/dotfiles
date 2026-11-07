import QtQuick
import Quickshell
import qs

// Right end: the two side panels, settings and the session menu as round buttons in one capsule.
BarPill {
    id: root
    strip: true

    component Button: BarCell {
        id: b
        property string icon
        property bool lit: false
        fill: lit ? BarStyle.accentContainer : "transparent"
        BarIcon { name: b.icon; color: b.lit ? BarStyle.onAccentContainer : BarStyle.text; fill: b.lit ? 1 : 0 }
    }

    Button { icon: "select_window"; tip: "Windows"; onTapped: Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "switcher", "toggle"]) }
    Button { icon: "tune"; tip: "Quick panel"; lit: BarState.sidebar === "left"; onTapped: BarState.toggleSidebar("left") }
    Button { icon: "dashboard"; tip: "Sections"; lit: BarState.sidebar === "right"; onTapped: BarState.toggleSidebar("right") }
    Button { icon: "settings"; tip: "Settings"; lit: GlobalStates.settingsOpen; onTapped: GlobalStates.settingsOpen = !GlobalStates.settingsOpen }
    Button { icon: "power_settings_new"; tip: "Session"; onTapped: GlobalStates.sessionOpen = true }
}
