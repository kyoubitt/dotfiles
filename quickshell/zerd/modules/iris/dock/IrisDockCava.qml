import QtQuick
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.iris.style

// A spectrum that lives inside the Dock's plate, behind the icons: soft rounded bars rising from the bottom edge,
// in the accent colour. It listens to the audio, and draws, only while something plays and the Dock is showing.
Item {
    id: root
    property int count: 40
    property bool vertical: false
    property real inset: 14
    readonly property bool wanted: (Config.options?.iris?.dock?.cava?.enable ?? true)
    readonly property bool playing: NowPlaying.isPlaying
    readonly property bool on: root.wanted && root.playing && root.visible && root.width > 0
    opacity: root.on ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 260 } }

    property int request: -1
    onOnChanged: {
        if (root.on && request < 0) request = CavaService.subscribe(root.count)
        else if (!root.on && request >= 0) { CavaService.unsubscribe(request); request = -1 }
    }
    Component.onDestruction: if (request >= 0) CavaService.unsubscribe(request)

    property var levels: new Array(root.count).fill(0)
    Timer {
        interval: 45; repeat: true; running: root.on
        onTriggered: {
            const p = CavaService.points, c = CavaService.normalizationCeiling, lv = root.levels
            for (let i = 0; i < root.count; i++) {
                const src = Math.min(root.count - 1, Math.floor(Math.abs(i - (root.count - 1) / 2) * 2))
                const v = Math.min(1, Math.pow(Math.max(0, (p[src] ?? 0) / c), 0.75))
                lv[i] = v > lv[i] ? lv[i] + (v - lv[i]) * 0.6 : lv[i] + (v - lv[i]) * 0.18
            }
            root.levels = lv.slice()
        }
    }

    readonly property real gap: 3
    readonly property real span: root.vertical ? root.height : root.width
    readonly property real barW: Math.max(2, (root.span - root.inset * 2 - root.gap * (root.count - 1)) / root.count)
    Repeater {
        model: root.count
        delegate: Rectangle {
            required property int index
            readonly property real lv: root.levels[index] ?? 0
            readonly property real len: 3 + lv * (root.vertical ? root.width : root.height) * 0.55
            radius: Math.min(width, height) / 2
            color: IrisStyle.accent
            opacity: 0.16 + 0.3 * lv
            // bass in the middle, like the player: bar index counts outward from the centre
            readonly property int slot: index
            width: root.vertical ? len : root.barW
            height: root.vertical ? root.barW : len
            x: root.vertical ? 0 : root.inset + slot * (root.barW + root.gap)
            y: root.vertical ? root.inset + slot * (root.barW + root.gap) : root.height - len
        }
    }
}
