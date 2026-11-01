pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// Draws the wallpaper and, when `source` changes, reveals the new picture over the old one with a
// transition: fade, a wipe from any side, an opening from the middle, a circle growing from a point,
// blinds, or a zoom. No shaders: clipped copies and masks. The kind and the circle's origin come from
// WallpaperState.request (the picker), or a random one.
Item {
    id: root

    property url source
    property url from: ""                  // what is on screen
    property url to: ""                    // what is being revealed
    property string kind: "fade"
    property real ox: 0.5
    property real oy: 0.5
    property real p: 0                     // progress, 0 to 1
    property bool running: false
    property bool finishing: false
    readonly property int blindCount: 12

    onSourceChanged: {
        if (root.from.toString() === "") { root.from = root.source; return }
        if (root.source === root.from && !root.running) return
        if (root.running) {
            // Interrupted: land on what was coming, then carry on with a quick fade.
            anim.stop()
            root.from = root.to
            root.running = false
            root.p = 0
            root.pending = { kind: "fade", x: 0.5, y: 0.5, quick: true }
        } else {
            root.pending = WallpaperState.take() ?? { kind: WallpaperState.pickKind(), x: 0.5, y: 0.5 }
        }
        root.to = root.source
        root.arm = true
        root.tryStart()
    }
    property var pending: null
    property bool arm: false

    function tryStart(): void {
        if (!root.arm || probe.status !== Image.Ready) return
        root.arm = false
        root.kind = root.pending.kind
        root.ox = root.pending.x ?? 0.5
        root.oy = root.pending.y ?? 0.5
        anim.duration = root.kind === "fade" ? (root.pending.quick ? 350 : 700) : (root.kind === "circle" || root.kind === "blinds" ? 1000 : 900)
        root.p = 0
        root.running = true
        anim.restart()
    }
    function finish(): void {
        root.from = root.to
        root.finishing = true
        settle.restart()
    }

    // Loads the incoming picture before anything moves, so a transition never starts on a blank.
    Image {
        id: probe
        source: root.to
        visible: false
        asynchronous: true
        cache: true
        sourceSize: Qt.size(root.width, root.height)
        onStatusChanged: root.tryStart()
    }

    NumberAnimation {
        id: anim
        target: root
        property: "p"
        from: 0; to: 1
        easing.type: Easing.InOutCubic
        onFinished: root.finish()
    }
    // The old picture stays until the new one is certainly drawn underneath.
    Timer { id: settle; interval: 120; onTriggered: { root.running = false; root.finishing = false; root.p = 0 } }

    Image {
        id: base
        anchors.fill: parent
        source: root.from
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize: Qt.size(root.width, root.height)
        scale: root.running && root.kind === "zoom" ? 1 + 0.07 * root.p : 1
        opacity: root.running && root.kind === "zoom" ? 1 - root.p : 1
    }

    // ---- The incoming picture, shown by whichever transition is running
    Item {
        id: fx
        anchors.fill: parent
        visible: root.running

        component Pic: Image {
            source: root.to
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize: Qt.size(root.width, root.height)
        }

        // fade and zoom
        Pic {
            anchors.fill: parent
            visible: root.kind === "fade" || root.kind === "zoom"
            opacity: root.p
            scale: root.kind === "zoom" ? 1.04 - 0.04 * root.p : 1
        }
        // wipes and the opening from the middle
        Item {
            id: wipe
            visible: root.kind.startsWith("wipe") || root.kind === "open"
            clip: true
            readonly property real q: root.p
            x: root.kind === "wipe-r" ? root.width * (1 - q) : (root.kind === "open" ? root.width * (1 - q) / 2 : 0)
            y: root.kind === "wipe-d" ? root.height * (1 - q) : 0
            width: (root.kind === "wipe-u" || root.kind === "wipe-d") ? root.width : root.width * q
            height: (root.kind === "wipe-u" || root.kind === "wipe-d") ? root.height * q : root.height
            Pic { x: -wipe.x; y: -wipe.y; width: root.width; height: root.height }
        }
        // a circle growing from the picked point
        Item {
            id: circle
            anchors.fill: parent
            visible: root.kind === "circle"
            Pic {
                id: circPic
                anchors.fill: parent
                layer.enabled: circle.visible
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: circMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }
            Item {
                id: circMask
                anchors.fill: parent
                layer.enabled: circle.visible
                visible: false
                readonly property real cx: root.ox * root.width
                readonly property real cy: root.oy * root.height
                readonly property real reach: Math.hypot(Math.max(cx, root.width - cx), Math.max(cy, root.height - cy))
                Rectangle {
                    readonly property real r: circMask.reach * root.p
                    x: circMask.cx - r; y: circMask.cy - r
                    width: 2 * r; height: 2 * r; radius: r
                    color: "black"
                }
            }
        }
        // blinds: vertical strips opening one after another
        Repeater {
            model: root.kind === "blinds" ? root.blindCount : 0
            delegate: Item {
                id: strip
                required property int index
                readonly property real w: root.width / root.blindCount
                readonly property real q: Math.max(0, Math.min(1, (root.p - (index / root.blindCount) * 0.5) / 0.5))
                x: index * w; y: 0
                width: w + 1; height: root.height * q
                clip: true
                Pic { x: -strip.x; y: 0; width: root.width; height: root.height }
            }
        }
    }
}
