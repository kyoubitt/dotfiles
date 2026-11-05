import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.lockScreen

// The user on the left (picture, name, uptime) with settings / lock / session on the right, then the time and date.
Item {
    id: root

    property string uptime: ""
    height: 104

    Process {
        running: true
        command: ["sh", "-c", "uptime -p | sed -e 's/^up //' -e 's/ years\?/y/;s/ weeks\?/w/;s/ days\?/d/;s/ hours\?/h/;s/ minutes\?/m/'"]
        stdout: StdioCollector { onStreamFinished: root.uptime = text.trim() }
    }

    Row {
        spacing: 12
        LockAvatar { size: 44 }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(40, root.width - 44 - 12 - 3 * 36 - 12 - 12)
            BarText { width: parent.width; elide: Text.ElideRight; text: Config.options?.account?.name || SystemInfo.displayName; font.pixelSize: 15; font.weight: Font.DemiBold }
            BarText { width: parent.width; elide: Text.ElideRight; text: root.uptime.length > 0 ? "up " + root.uptime : ""; color: BarStyle.subtext; font.pixelSize: 12 }
        }
    }
    Column {
        y: 54
        BarText { text: DateTime.time; font.pixelSize: 30; font.weight: Font.DemiBold }
        BarText { text: Qt.formatDate(new Date(), "dddd, d MMMM"); color: BarStyle.subtext; font.pixelSize: 12 }
    }
    Row {
        // Level with the time line (40 px tall), same right edge as everything below.
        anchors.right: parent.right
        y: 6
        spacing: 6
        component Round: BarButton {
            id: rb
            property string icon
            property string tip
            tone: "outlined"
            width: 36; height: 36; radius: 18
            onTapped: rb.fire()
            signal fire()
            BarIcon { anchors.centerIn: parent; name: rb.icon; size: 18; color: rb.ink }
            BarTip { text: rb.tip; external: rb.hovered }
        }
        Round { icon: "settings"; tip: "Settings"; onFire: { BarState.closeAll(); Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "settings", "open"]) } }
        Round { icon: "lock"; tip: "Lock"; onFire: { BarState.closeAll(); Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"]) } }
        Round { icon: "power_settings_new"; tip: "Session"; onFire: { BarState.closeAll(); GlobalStates.sessionOpen = true } }
    }
}
