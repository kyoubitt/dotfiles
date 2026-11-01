import QtQuick
import QtQuick.Effects
import qs.services
import qs.services.deferred
import qs.modules.music

// A mirrored spectrum: bass in the middle, highs toward the edges, filled with the song's colour, with a soft glow, caps that
// drift down and a reflection. When the line being sung changes (pulseKey) the whole thing swells and a light runs outward;
// with no lyrics it swells on the beat. It only listens to the audio while it is on screen.
Item {
    id: root
    property int half: 40
    readonly property int count: half * 2
    property color tint: MusicStore.accent
    property int pulseKey: -1          // changes when the sung line changes
    property bool lyricsDriven: pulseKey >= 0
    property int request: -1
    implicitHeight: 130
    clip: false

    onVisibleChanged: { if (visible && request < 0) request = CavaService.subscribe(half); else if (!visible && request >= 0) { CavaService.unsubscribe(request); request = -1 } }
    Component.onCompleted: if (visible) request = CavaService.subscribe(half)
    Component.onDestruction: if (request >= 0) CavaService.unsubscribe(request)

    readonly property real gap: 9
    readonly property real barW: Math.max(2, (width - gap * (count - 1)) / count)
    readonly property real floorY: height * 0.8

    // the swell: 1 right after a line change or a beat, easing back to 0
    property real kick: 0
    NumberAnimation { id: kickAnim; target: root; property: "kick"; from: 1; to: 0; duration: 420; easing.type: Easing.OutCubic }
    function swell(): void { kickAnim.restart(); ring.restart() }
    onPulseKeyChanged: if (pulseKey >= 0 && visible) swell()
    readonly property real bass: { const p = CavaService.points; return Math.min(1, ((p[0] ?? 0) + (p[1] ?? 0) + (p[2] ?? 0)) / 3 / CavaService.normalizationCeiling) }
    property real lastBass: 0
    onBassChanged: { if (!root.lyricsDriven && visible && bass > 0.72 && lastBass < 0.5) swell(); lastBass = bass }

    // a glow under the bars
    Rectangle {
        x: 0; width: parent.width; height: 60; y: root.floorY - 40; radius: 30
        gradient: Gradient { GradientStop { position: 0; color: "#00000000" } GradientStop { position: 1; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.16 + 0.22 * root.kick) } }
    }
    // the light that runs outward along the floor
    Rectangle {
        id: ringDot
        anchors.verticalCenter: undefined; y: root.floorY + 1; height: 2; radius: 1
        width: root.width * ringT; x: (root.width - width) / 2; opacity: (1 - ringT) * 0.9
        property real ringT: 0
        color: Qt.lighter(root.tint, 1.5)
    }
    NumberAnimation { id: ring; target: ringDot; property: "ringT"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }

    // one timer moves every bar (instead of an animation and a binding per bar): rise fast, fall slowly
    readonly property var levels: new Array(root.count).fill(0)
    property var shown: new Array(root.count).fill(0)
    property var peaks: new Array(root.count).fill(0)
    Timer {
        interval: 40; repeat: true; running: root.visible
        onTriggered: {
            const p = CavaService.points, c = CavaService.normalizationCeiling, h = root.half
            const sh = root.shown, pk = root.peaks
            for (let i = 0; i < root.count; i++) {
                const src = i < h ? h - 1 - i : i - h
                const a = p[src] ?? 0, l = p[src - 1] ?? a, r = p[src + 1] ?? a
                const v = Math.max(0, (a * 0.6 + l * 0.2 + r * 0.2) / c)
                const f = src / h
                const gain = 1.0 + 0.5 * Math.exp(-Math.pow((f - 0.28) / 0.22, 2)) + 0.25 * f
                const raw = Math.min(1, Math.pow(Math.min(1, v), 0.7) * gain)
                sh[i] = raw > sh[i] ? sh[i] + (raw - sh[i]) * 0.65 : sh[i] + (raw - sh[i]) * 0.2
                pk[i] = sh[i] > pk[i] ? sh[i] : Math.max(sh[i], pk[i] - 0.012)
            }
            root.shown = sh.slice(); root.peaks = pk.slice()
        }
    }
    Repeater {
        model: root.count
        delegate: Item {
            id: b
            required property int index
            readonly property int src: index < root.half ? root.half - 1 - index : index - root.half
            readonly property real level: root.shown[index] ?? 0
            readonly property real peak: root.peaks[index] ?? 0
            x: index * (root.barW + root.gap); width: root.barW
            readonly property real swell: 1 + root.kick * 0.2 * (1 - src / root.half * 0.6)
            readonly property real h: Math.min(root.floorY - 4, (5 + level * (root.floorY - 8)) * swell)
            Rectangle { width: parent.width; height: b.h; y: root.floorY - height; radius: width / 2; color: Qt.lighter(root.tint, 1.15 + 0.3 * root.kick); opacity: 0.94 }
            Rectangle { width: parent.width; height: 3; radius: 1.5; y: root.floorY - (5 + b.peak * (root.floorY - 8)) * b.swell - 8; color: "#ffffff"; opacity: 0.7 }
        }
    }
}
