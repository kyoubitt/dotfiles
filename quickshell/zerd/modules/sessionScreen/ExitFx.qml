import QtQuick
import qs.modules.bars

// What the power menu plays once a capsule has fired and its command has not gone out yet. The capsule's liquid
// bursts out of the capsule and floods the whole window in its colour, then, by kind:
//   fade   the colour goes to black (Log out)
//   sleep  it dims to near black while the capsule's moon flies to the middle and breathes (Sleep)
//   crt    the screen collapses to a bright line, then a dot, then black, like a tube switching off (Restart, Shut down)
// Everything on screen is a function of one clock, `t` in milliseconds since the capsule fired, so a frame is the same
// whether it is played or sought to. fire() is the moment the command should go out, finished() the moment the window
// can go; between them the last frame is held, in case the command is refused and the desktop has to come back.
// Nothing is drawn while idle, and Lock never uses it: it keeps the blurred backdrop up for the lock screen.
Item {
    id: root

    property string kind: "fade"
    property color tone: "#f0b35a"
    property color ink: BarStyle.onAccent       // the dark colour of the icon on the liquid
    property string icon: ""
    property string label: ""
    // the fired capsule as it is on screen, in this item's coordinates
    property real faceX: 0
    property real faceY: 0
    property real faceW: 144
    property real faceH: 196
    property real faceRadius: 40

    readonly property real floodMs: kind === "sleep" ? 340 : 300
    readonly property real tailMs: kind === "crt" ? 480 : (kind === "sleep" ? 340 : 240)
    readonly property real fireAt: floodMs + tailMs                  // 540 fade, 680 sleep, 780 crt
    property real holdMs: kind === "crt" ? 4500 : (kind === "sleep" ? 1900 : 2600)
    readonly property real wakeMs: 300
    readonly property real totalMs: fireAt + holdMs + wakeMs

    property real t: -1                                              // -1 while idle
    readonly property bool running: t >= 0 && t < totalMs
    readonly property bool covered: t >= floodMs                     // the flood fills the window: what is under it can stop drawing
    property bool sent: false
    property bool done: false
    signal fire()
    signal finished()

    // the three stages, each 0..1
    readonly property real flood: inOut(c01(t / floodMs))
    readonly property real tail: c01((t - floodMs) / tailMs)
    readonly property real wake: c01((t - fireAt - holdMs) / wakeMs)
    readonly property real crtLine: kind === "crt" ? inCubic(c01(tail / 0.42)) : 0       // squeezed to a line
    readonly property real crtDot: kind === "crt" ? outCubic(c01((tail - 0.42) / 0.31)) : 0   // the line pulled in to a dot
    readonly property real crtOut: kind === "crt" ? c01((tail - 0.73) / 0.27) : 0        // the dot goes out

    readonly property real unit: faceW / 144
    readonly property real cx: faceX + faceW / 2
    readonly property real cy: faceY + faceH / 2
    // diameter of a circle around the capsule that reaches the farthest corner
    readonly property real reach: 2 * Math.sqrt(Math.pow(Math.max(cx, width - cx), 2) + Math.pow(Math.max(cy, height - cy), 2)) + 4
    readonly property color black: Qt.rgba(0, 0, 0, 1)
    readonly property color nearBlack: Qt.rgba(0.02, 0.02, 0.035, 1)

    function c01(x: real): real { return Math.max(0, Math.min(1, x)) }
    function inOut(x: real): real { return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2 }
    function inCubic(x: real): real { return x * x * x }
    function outCubic(x: real): real { return 1 - Math.pow(1 - x, 3) }
    function mix(a: color, b: color, k: real): color { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1) }

    // Start from the fired capsule: its place on screen (x, y, width, height, corner radius) and what it showed.
    function begin(kind: string, tone: color, icon: string, label: string, x: real, y: real, w: real, h: real, r: real): void {
        clock.stop()
        root.kind = kind
        root.tone = tone
        root.icon = icon
        root.label = label
        root.faceX = x; root.faceY = y; root.faceW = w; root.faceH = h; root.faceRadius = r
        root.sent = false
        root.done = false
        clock.from = 0
        clock.to = root.totalMs
        clock.duration = root.totalMs
        root.t = 0
        clock.start()
    }
    // Go straight to a moment and stop there (what the tests use).
    function seek(ms: real): void { clock.stop(); root.t = ms }
    function cancel(): void { clock.stop(); root.t = -1; root.sent = false; root.done = false }
    // Skip the rest of the hold: the desktop comes back.
    function wakeNow(): void {
        const at = root.fireAt + root.holdMs
        if (!root.running || root.t >= at) return
        clock.stop()
        root.t = at
        clock.from = at
        clock.to = root.totalMs
        clock.duration = root.wakeMs
        clock.start()
    }
    function complete(): void {
        if (root.done) return
        root.done = true
        root.finished()
    }
    onTChanged: {
        if (!root.sent && root.t >= root.fireAt) { root.sent = true; root.fire() }
        if (root.t >= root.totalMs) root.complete()
    }

    visible: running
    clip: true

    NumberAnimation { id: clock; target: root; property: "t"; easing.type: Easing.Linear }
    // If frames stop coming (the output is off) the window still has to go.
    Timer { interval: root.totalMs + 600; running: root.t >= 0 && !root.done; onTriggered: root.complete() }
    // After a suspend the wall clock has jumped but the animation clock has not: that is the machine waking up.
    Timer {
        property real last: 0
        interval: 120; repeat: true
        running: root.kind === "sleep" && root.sent && root.running
        onRunningChanged: if (running) last = Date.now()
        onTriggered: { const now = Date.now(); if (now - last > 1500) root.wakeNow(); last = now }
    }

    // the liquid leaving the capsule: it starts as the capsule's own shape and ends as a circle past every corner
    Rectangle {
        objectName: "flood"
        visible: root.t >= 0 && !root.covered
        width: root.faceW + (root.reach - root.faceW) * root.flood
        height: root.faceH + (root.reach - root.faceH) * root.flood
        x: root.cx - width / 2
        y: root.cy - height / 2
        radius: root.faceRadius + (root.reach / 2 - root.faceRadius) * root.flood
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0; color: root.mix(Qt.darker(root.tone, 1.1), root.tone, root.flood) }
            GradientStop { position: 1; color: root.tone }
        }
    }

    // the whole window in one colour
    Rectangle {
        objectName: "solid"
        anchors.fill: parent
        visible: root.covered
        opacity: 1 - root.wake
        color: root.kind === "crt" ? root.black : root.mix(root.tone, root.kind === "sleep" ? root.nearBlack : root.black, root.inOut(root.tail))
    }

    // CRT: the glow around the line, then the screen itself
    Rectangle {
        objectName: "bloom"
        visible: root.kind === "crt" && root.covered && root.crtLine > 0 && root.crtOut < 1
        width: Math.max(8, root.width * (1 - root.crtDot)) + 60 * root.crtLine
        height: 44 * root.crtLine
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        opacity: root.crtLine * (1 - root.crtOut)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.34) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
    Rectangle {
        objectName: "sheet"
        visible: root.kind === "crt" && root.covered && root.crtOut < 1
        width: Math.max(6, root.width * (1 - root.crtDot))
        height: Math.max(3 + 3 * root.crtDot, root.height * (1 - root.crtLine))
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        radius: Math.min(3, width / 2, height / 2)
        antialiasing: true
        color: root.mix(root.tone, Qt.rgba(1, 1, 1, 1), root.crtLine)
        opacity: 1 - root.crtOut
        scale: 1 - 0.5 * root.crtOut
    }

    // the capsule's name goes first
    BarText {
        visible: root.t >= 0
        x: Math.round(root.cx - width / 2)
        y: Math.round(root.faceY + root.faceH * 138 / 196 - height / 2)
        text: root.label
        font.pixelSize: Math.round(15 * root.unit)
        color: root.ink
        opacity: 1 - root.c01(root.flood * 3.2)
    }

    // the capsule's icon: it fades out, or for Sleep it is the moon that flies to the middle and breathes
    BarIcon {
        id: glyph
        objectName: "glyph"
        readonly property bool moon: root.kind === "sleep"
        readonly property real fly: moon ? root.flood : 0
        readonly property real iconY: root.faceY + root.faceH * 77 / 196
        readonly property real breath: 0.5 - 0.5 * Math.cos(Math.max(0, root.t - root.floodMs) / 3200 * 2 * Math.PI)
        visible: root.t >= 0
        name: root.icon
        fill: moon ? root.flood : 0
        size: moon ? 50 * root.unit + (128 - 50 * root.unit) * fly : 50 * root.unit + 12 * root.flood
        x: Math.round((moon ? root.cx + (root.width / 2 - root.cx) * fly : root.cx) - width / 2)
        y: Math.round((moon ? iconY + (root.height / 2 - iconY) * fly : iconY) - height / 2)
        color: moon ? root.mix(root.ink, Qt.lighter(root.tone, 1.6), root.inOut(root.tail)) : root.ink
        scale: moon ? 1 + 0.07 * breath * root.tail : 1
        opacity: (moon ? 1 - 0.35 * (1 - breath) * root.tail : 1 - root.c01(root.flood * 2.4)) * (1 - root.wake)
    }
}
