import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common

// The top row of both side panels, one style: a round tile on the left (the account picture on the quick panel, a glyph
// on the sections panel), two lines of text, and the panel's buttons on the right (they are this item's children).
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    // The account picture, and an uptime line when no subtitle is given, instead of the glyph tile.
    property bool avatar: false
    default property alias buttons: btnRow.data
    property string uptime: ""
    height: 48

    // The same places the lock screen looks for a picture, first one that loads wins.
    readonly property var candidates: [
        Config.options?.account?.avatar ?? "",
        Directories.userAvatarPathAccountsService,
        Directories.userAvatarPathRicersAndWeirdSystems,
        Directories.userAvatarPathRicersAndWeirdSystems2
    ].filter(p => p && p.length > 0)
    property int tryIndex: 0
    onCandidatesChanged: tryIndex = 0
    readonly property bool hasPicture: root.avatar && picture.status === Image.Ready

    function refreshUptime(): void { if (root.avatar && !upProc.running) upProc.running = true }
    Component.onCompleted: root.refreshUptime()
    onVisibleChanged: if (visible) root.refreshUptime()
    Process {
        id: upProc
        command: ["sh", "-c", "uptime -p | sed -e 's/^up //' -e 's/ years\\?/y/;s/ months\\?/mo/;s/ weeks\\?/w/;s/ days\\?/d/;s/ hours\\?/h/;s/ minutes\\?/m/' -e 's/,//g'"]
        stdout: StdioCollector { onStreamFinished: root.uptime = text.trim() }
    }

    ClippingRectangle {
        id: tile
        width: 44; height: 44; radius: 23
        anchors.verticalCenter: parent.verticalCenter
        color: root.avatar ? BarStyle.cardHigh : BarStyle.accentContainer
        border.width: root.avatar ? 2 : 0
        border.color: BarStyle.accent
        Image {
            id: picture
            anchors.fill: parent
            visible: root.avatar && status === Image.Ready
            source: root.avatar && root.tryIndex < root.candidates.length ? "file://" + root.candidates[root.tryIndex] : ""
            sourceSize: Qt.size(88, 88)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            asynchronous: true
            // a missing file errors; move on to the next place to look
            onStatusChanged: if (status === Image.Error) root.tryIndex += 1
        }
        // no picture: the first letter of the name
        BarText {
            anchors.centerIn: parent
            visible: root.avatar && !root.hasPicture
            text: root.title.length > 0 ? root.title[0].toUpperCase() : "?"
            font.pixelSize: 19; font.weight: Font.DemiBold; color: BarStyle.accent
        }
        BarIcon { anchors.centerIn: parent; visible: !root.avatar; name: root.icon; size: 22; fill: 1; color: BarStyle.accent }
    }

    Column {
        x: tile.width + 12
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(40, root.width - tile.width - 12 - btnRow.width - 12)
        BarText { width: parent.width; elide: Text.ElideRight; text: root.title; font.pixelSize: 15; font.weight: Font.DemiBold }
        BarText { width: parent.width; elide: Text.ElideRight; font.pixelSize: 12; color: BarStyle.subtext
            text: root.subtitle.length > 0 ? root.subtitle : (root.avatar && root.uptime.length > 0 ? "up " + root.uptime : "") }
    }

    Row {
        id: btnRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    }
}
