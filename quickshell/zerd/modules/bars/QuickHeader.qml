import QtQuick
import Quickshell
import qs
import qs.services

// Under the panel's own header: the time and date on the left, settings / lock / session as one capsule on the right
// (the button group of end-4's sidebar). The picture, name and uptime live in the header row above.
Item {
    id: root

    height: 56

    Column {
        anchors.verticalCenter: parent.verticalCenter
        BarText { text: DateTime.time; font.pixelSize: 30; font.weight: Font.DemiBold }
        BarText { text: Qt.formatDate(DateTime.clock.date, "dddd, d MMMM"); color: BarStyle.subtext; font.pixelSize: 12 }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: group.width + 8; height: 44; radius: 22
        color: BarStyle.card
        border.width: 1; border.color: BarStyle.edge
        Row {
            id: group
            x: 4; y: 4
            spacing: 2
            PanelButton { tone: "plain"; size: 36; icon: "settings"; tip: "Settings"; onTapped: { BarState.closeAll(); Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "settings", "open"]) } }
            PanelButton { tone: "plain"; size: 36; icon: "lock"; tip: "Lock"; onTapped: { BarState.closeAll(); Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"]) } }
            PanelButton { tone: "plain"; size: 36; icon: "power_settings_new"; tip: "Session"; onTapped: { BarState.closeAll(); GlobalStates.sessionOpen = true } }
        }
    }
}
