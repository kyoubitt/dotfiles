import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.startMenu
import qs.services

// Round profile picture in an accent ring. Tries the configured avatar, then
// AccountsService, ~/.face and ~/.face.icon; falls back to the user's first
// letter when none of them load.
//
// `state` (Item.state, set by LockSurface) turns the ring into the password check's progress:
//   verifying - the ring dims and an arc spins round it
//   success   - the arc closes into a full ring with a small pop
//   fail      - the ring flashes red and fades back
Item {
    id: root

    property real size: 100
    property color errorColor: Appearance.colors.colError
    state: "typing"
    states: [
        State { name: "typing" },
        State { name: "verifying" },
        State { name: "success" },
        State { name: "fail" }
    ]

    property real arcStart: 270      // degrees
    property real arcSweep: 0
    property real dim: 0             // 0..1, how far the plain ring steps back
    property real flash: 0           // 0..1, red
    property real pop: 1
    scale: pop

    onStateChanged: {
        spin.stop(); breathe.stop(); toFull.stop(); toNone.stop(); flashAnim.stop(); popAnim.stop()
        if (state === "verifying") {
            arcStart = 270
            arcSweep = 0
            dimTo.to = 1; dimTo.restart()
            spin.restart(); breathe.restart()
        } else if (state === "success") {
            arcStart = ((arcStart % 360) + 360) % 360
            toFull.restart(); popAnim.restart()
            dimTo.to = 0; dimTo.restart()
        } else if (state === "fail") {
            toNone.restart(); flashAnim.restart()
            dimTo.to = 0; dimTo.restart()
        } else {
            toNone.restart()
            dimTo.to = 0; dimTo.restart()
        }
    }
    NumberAnimation { id: dimTo; target: root; property: "dim"; duration: 200 }
    NumberAnimation { id: spin; target: root; property: "arcStart"; from: 270; to: 630; duration: 1000; loops: Animation.Infinite }
    SequentialAnimation {
        id: breathe
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "arcSweep"; to: 230; duration: 650; easing.type: Easing.InOutCubic }
        NumberAnimation { target: root; property: "arcSweep"; to: 50; duration: 650; easing.type: Easing.InOutCubic }
    }
    ParallelAnimation {
        id: toFull
        NumberAnimation { target: root; property: "arcSweep"; to: 360; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "arcStart"; to: 270; duration: 220; easing.type: Easing.OutCubic }
    }
    NumberAnimation { id: toNone; target: root; property: "arcSweep"; to: 0; duration: 160; easing.type: Easing.OutCubic }
    NumberAnimation { id: flashAnim; target: root; property: "flash"; from: 1; to: 0; duration: 900; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: root; property: "pop"; to: 1.07; duration: 110; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "pop"; to: 1; duration: 150; easing.type: Easing.InOutCubic }
    }

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
        color: ColorUtils.applyAlpha(Qt.tint(SMColors.accent, Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, root.flash)), 0.18)
        border.width: 2
        border.color: ColorUtils.applyAlpha(Qt.tint(SMColors.accent, Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, root.flash)), 1 - 0.7 * root.dim)
    }

    // the progress arc, over the ring
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: SMColors.accent
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.size / 2 - 1.5
                radiusY: root.size / 2 - 1.5
                startAngle: root.arcStart
                sweepAngle: root.arcSweep
            }
        }
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
