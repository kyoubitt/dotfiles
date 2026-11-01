import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.startMenu

// Compact cava visualizer: thin rounded bars mirrored around a centre line,
// brightest in the middle and fading toward the edges. `points` is the raw
// cava output (0..1000 per bar).
Item {
    id: root

    property list<real> points: []
    property int bars: 32

    implicitWidth: bars * 13
    implicitHeight: 64

    Row {
        anchors.centerIn: parent
        spacing: 7
        height: parent.height

        Repeater {
            model: root.bars
            delegate: Item {
                id: bar
                required property int index
                readonly property real level: root.points.length > 0
                    ? Math.max(0, Math.min(1, (root.points[Math.min(bar.index, root.points.length - 1)] ?? 0) / 1000))
                    : 0
                // 1 in the middle, ~0.3 at the edges
                readonly property real centre: 1 - 0.7 * Math.abs(bar.index - (root.bars - 1) / 2) / ((root.bars - 1) / 2)

                width: 6
                height: root.height

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 6 + bar.level * (root.height - 6)
                    radius: width / 2
                    antialiasing: true
                    // accent in the middle, fg toward the edges
                    color: Qt.tint(SMColors.fg, ColorUtils.applyAlpha(SMColors.accent, bar.centre))
                    opacity: (0.35 + bar.level * 0.65) * (0.35 + 0.65 * bar.centre)

                    Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                }
            }
        }
    }
}
