import QtQuick
import Quickshell
import qs

// Right end: the two side panels, settings and the session menu as round buttons in one capsule.
BarPill {
    id: root

    component Button: Item {
        id: b
        property string icon
        property string tip
        property bool lit: false
        signal tapped()
        implicitWidth: 28; implicitHeight: 28
        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: ma.pressed ? BarStyle.border : (maHover.hovered ? BarStyle.plateHover : "transparent")
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        BarIcon { anchors.centerIn: parent; name: b.icon; size: 18; color: b.lit ? BarStyle.accent : BarStyle.text }
        MouseArea { id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: b.tapped() }
        HoverHandler { id: maHover }
        BarTip { text: b.tip }
    }

    Button { icon: "select_window"; tip: "Windows"; onTapped: Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "switcher", "toggle"]) }
    Button { icon: "tune"; tip: "Quick panel"; lit: BarState.sidebar === "left"; onTapped: BarState.toggleSidebar("left") }
    Button { icon: "dashboard"; tip: "Sections"; lit: BarState.sidebar === "right"; onTapped: BarState.toggleSidebar("right") }
    Button { icon: "settings"; tip: "Settings"; lit: GlobalStates.settingsOpen; onTapped: GlobalStates.settingsOpen = !GlobalStates.settingsOpen }
    Button { icon: "power_settings_new"; tip: "Session"; onTapped: GlobalStates.sessionOpen = true }
}
