import QtQuick
import qs.modules.iris.style

// Popup body that grows out of a rectangle (`origin`, in the parent's
// coordinates) into this item's own geometry while its content fades in.
// Simplified from iNiR's version: no glass field, no spring; one eased
// progress value.
Item {
    id: root

    property bool open: false
    property bool contentReady: true
    property string motionSurface: ""
    property var origin: null
    property real radius: IrisStyle.radius
    property color color: IrisStyle.surface
    property color light: "transparent"
    property string lightFrom: "top"
    property bool fieldBacked: false
    property int animationDuration: 0
    default property alias content: contentHost.data

    signal closed()

    readonly property real target: root.open && root.contentReady && root.width > 0 && root.height > 0 ? 1 : 0
    property real progress: 0
    Behavior on progress {
        enabled: IrisStyle.motionEnabled
        NumberAnimation {
            duration: root.animationDuration > 0 && root.target > 0 ? Math.min(root.animationDuration, 220) : IrisStyle.duration(root.target > 0 ? 200 : 110)
            easing.type: root.target > 0 ? Easing.OutCubic : Easing.InCubic
        }
    }
    onTargetChanged: root.progress = root.target
    onProgressChanged: if (root.progress === 0 && !root.open) root.closed()

    readonly property bool grows: root.origin !== null && root.origin !== undefined
    readonly property real t: root.grows ? root.progress : 1
    readonly property rect bodyRect: {
        const o = root.origin
        if (!root.grows) return Qt.rect(root.x, root.y, root.width, root.height)
        const k = root.progress
        return Qt.rect(o.x + (root.x - o.x) * k, o.y + (root.y - o.y) * k,
            o.width + (root.width - o.width) * k, o.height + (root.height - o.height) * k)
    }

    Rectangle {
        x: root.bodyRect.x - root.x
        y: root.bodyRect.y - root.y
        width: root.bodyRect.width
        height: root.bodyRect.height
        radius: root.grows ? Math.min(root.origin.radius ?? root.radius, root.radius) + (root.radius - Math.min(root.origin.radius ?? root.radius, root.radius)) * root.progress : root.radius
        color: root.color
        opacity: root.grows ? 1 : Math.min(1, root.progress * 1.6)
        antialiasing: true
        border.width: 1
        border.color: IrisStyle.hairlineStrong
    }

    Item {
        id: contentHost
        anchors.fill: parent
        opacity: Math.max(0, Math.min(1, (root.progress - 0.3) / 0.7))
        scale: 0.965 + 0.035 * root.progress
        transformOrigin: root.lightFrom === "top" ? Item.Top : Item.Bottom
    }
}
