import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Time, date and uptime on the left; lock and session on the right.
Item {
    id: root

    property string uptime: ""
    height: 56

    Process {
        running: true
        command: ["sh", "-c", "uptime -p | sed 's/^up //'"]
        stdout: StdioCollector { onStreamFinished: root.uptime = text.trim() }
    }

    Column {
        BarText { text: DateTime.time; font.pixelSize: 30; font.weight: Font.DemiBold }
        BarText { text: Qt.formatDate(new Date(), "dddd, d MMMM") + (root.uptime.length > 0 ? "  ·  up " + root.uptime : ""); color: BarStyle.subtext; font.pixelSize: 12 }
    }
    Row {
        // Level with the time line (40 px tall), same right edge as everything below.
        anchors.right: parent.right
        y: 4
        spacing: 6
        component Round: Rectangle {
            id: rb
            property string icon
            property string tip
            signal tapped()
            width: 32; height: 32; radius: 16
            color: ma.pressed ? BarStyle.border : (maHv.hovered ? BarStyle.plateHover : "transparent")
            border.width: 1; border.color: BarStyle.border
            Behavior on color { ColorAnimation { duration: 100 } }
            BarIcon { anchors.centerIn: parent; name: rb.icon; size: 17 }
            MouseArea { id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rb.tapped() }
            HoverHandler { id: maHv }
            BarTip { text: rb.tip; external: maHv.hovered }
        }
        Round { icon: "settings"; tip: "Settings"; onTapped: { BarState.closeAll(); Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "settings", "open"]) } }
        Round { icon: "lock"; tip: "Lock"; onTapped: { BarState.closeAll(); Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"]) } }
        Round { icon: "power_settings_new"; tip: "Session"; onTapped: { BarState.closeAll(); GlobalStates.sessionOpen = true } }
    }
}
