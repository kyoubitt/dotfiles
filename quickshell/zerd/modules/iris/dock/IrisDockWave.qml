import QtQuick
import QtQuick.Shapes
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.iris.style

// The spectrum as one smooth, soft hill along the bottom of the screen, on both sides of the Dock and behind it.
// It listens to the audio, and redraws, only while a song plays.
Item {
    id: root
    readonly property int bands: 48
    readonly property int steps: 140
    readonly property bool playing: NowPlaying.isPlaying
    readonly property bool on: root.playing && root.visible && root.width > 0
    opacity: root.on ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    property int request: -1
    onOnChanged: {
        if (root.on && request < 0) request = CavaService.subscribe(root.bands)
        else if (!root.on && request >= 0) { CavaService.unsubscribe(request); request = -1 }
    }
    Component.onDestruction: if (request >= 0) CavaService.unsubscribe(request)

    property var levels: new Array(root.bands).fill(0)      // smoothed across neighbours, what the hill is drawn from
    property var raw: new Array(root.bands).fill(0)         // the moving values, rising fast and falling slowly
    Timer {
        interval: 40; repeat: true; running: root.on
        onTriggered: {
            const p = CavaService.points, c = CavaService.normalizationCeiling, lv = root.raw, n = root.bands
            for (let i = 0; i < n; i++) {
                const v = Math.min(1, Math.pow(Math.max(0, (p[i] ?? 0) / c), 0.75))
                lv[i] = v > lv[i] ? lv[i] + (v - lv[i]) * 0.45 : lv[i] + (v - lv[i]) * 0.1
            }
            // a wide soft blur across neighbours: one round hill, not spikes
            const sm = new Array(n)
            for (let i = 0; i < n; i++) {
                const g = k => lv[Math.max(0, Math.min(n - 1, i + k))]
                sm[i] = (g(-3) + 2 * g(-2) + 3 * g(-1) + 4 * g(0) + 3 * g(1) + 2 * g(2) + g(3)) / 16
            }
            root.levels = sm
        }
    }

    // height of the hill at x (0..1): bass towards the sides, a dip in the middle where the Dock is, a taper at the very edge
    function at(x: real): real {
        const s = Math.abs(x - 0.5) * 2                       // 0 in the middle, 1 at the edges
        const f = (1 - s) * (root.bands - 1)
        const i = Math.max(0, Math.min(root.bands - 2, Math.floor(f))), t = f - i
        const a = (root.levels[i - 1] ?? root.levels[i]) * 0.25 + root.levels[i] * 0.5 + root.levels[i + 1] * 0.25
        const b = root.levels[i] * 0.25 + root.levels[i + 1] * 0.5 + (root.levels[i + 2] ?? root.levels[i + 1]) * 0.25
        const v = a + (b - a) * (t * t * (3 - 2 * t))         // smooth between neighbours
        const dip = 0.3 + 0.7 * Math.min(1, s / 0.55)          // quiet behind the Dock
        const edge = Math.min(1, (1 - s) * 6 + 0.0) > 0 ? Math.min(1, (1 - s) * 8) : 0   // taper to nothing at the screen edge
        return v * dip * Math.min(1, edge + 0.0) 
    }
    function build(spread: real, lift: real, closed: bool): var {
        const pts = []
        const w = root.width, h = root.height
        void root.levels
        if (closed) pts.push(Qt.point(0, h))
        for (let k = 0; k <= root.steps; k++) {
            const x = k / root.steps
            let v = root.at(x)
            if (spread > 0) { v = (v * 2 + root.at(Math.max(0, x - spread)) + root.at(Math.min(1, x + spread))) / 4 }
            pts.push(Qt.point(x * w, h - v * h * lift - 1))
        }
        if (closed) pts.push(Qt.point(w, h))
        return pts
    }
    readonly property var outlineWide: root.build(0.06, 1.0, true)
    readonly property var crest: root.build(0, 0.92, false)
    readonly property var outline: {
        const pts = []
        const w = root.width, h = root.height
        void root.levels
        pts.push(Qt.point(0, h))
        for (let k = 0; k <= root.steps; k++) {
            const x = k / root.steps
            pts.push(Qt.point(x * w, h - root.at(x) * h * 0.92 - 1))
        }
        pts.push(Qt.point(w, h))
        return pts
    }

    // a fainter, wider copy behind the hill gives it depth; a thin light line runs along the crest
    readonly property color tint: Qt.lighter(IrisStyle.accent, 1.25)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: root.height
                GradientStop { position: 0.0; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.14) }
            }
            PathPolyline { path: root.outlineWide }
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: root.height
                GradientStop { position: 0.0; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.0) }
                GradientStop { position: 0.5; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.20) }
                GradientStop { position: 1.0; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.40) }
            }
            PathPolyline { path: root.outline }
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.55); strokeWidth: 1.2; fillColor: "transparent"
            PathPolyline { path: root.crest }
        }
    }
}
