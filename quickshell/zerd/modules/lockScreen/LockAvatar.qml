import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.startMenu
import qs.services

// Round profile picture in an accent ring. Tries the configured avatar, then
// AccountsService, ~/.face and ~/.face.icon; falls back to the user's first
// letter when none of them load.
Item {
    id: root

    property real size: 100

    readonly property var candidates: [
        Config.options?.account?.avatar ?? "",
        Directories.userAvatarPathAccountsService,
        Directories.userAvatarPathRicersAndWeirdSystems,
        Directories.userAvatarPathRicersAndWeirdSystems2,
    ].filter(p => p && p.length > 0)

    property int tryIndex: 0
    onCandidatesChanged: tryIndex = 0

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: ColorUtils.applyAlpha(SMColors.accent, 0.18)
        border.width: 2
        border.color: SMColors.accent
    }

    Image {
        id: picture
        anchors.centerIn: parent
        width: root.size - 8
        height: root.size - 8
        visible: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.size - 8, root.size - 8)
        mipmap: true
        smooth: true
        antialiasing: true
        source: root.tryIndex < root.candidates.length ? "file://" + root.candidates[root.tryIndex] : ""
        // A missing file errors; move on to the next candidate.
        onStatusChanged: if (status === Image.Error) root.tryIndex += 1
    }

    Item {
        id: mask
        anchors.fill: picture
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.samples: 4
        Rectangle { anchors.fill: parent; radius: width / 2; antialiasing: true }
    }

    MultiEffect {
        anchors.fill: picture
        source: picture
        maskEnabled: true
        maskSource: mask
        visible: picture.status === Image.Ready
    }

    LockText {
        anchors.centerIn: parent
        visible: picture.status !== Image.Ready
        text: SystemInfo.username.length > 0 ? SystemInfo.username[0].toUpperCase() : "?"
        color: SMColors.accent
        font.pixelSize: root.size * 0.44
        font.bold: true
    }
}
