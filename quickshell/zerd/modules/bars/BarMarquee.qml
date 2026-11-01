import QtQuick
import QtQuick.Effects

// One line of text. If it fits it stays still; if not it scrolls on a loop, Material-style: it holds for a
// moment, glides one full lap (the text comes round again after a gap, so there is no jump back), and the
// two ends fade out so the text slides under the edge instead of being cut off.
Item {
    id: root

    property string text: ""
    property color color: BarStyle.text
    property int pixelSize: BarStyle.fontSize
    property int weight: Font.Medium
    // Pixels per second, the hold at the start of each lap, and the gap between the end and the start of the text.
    property real speed: 34
    property int rest: 1600
    property int gap: 36
    readonly property int fade: 14

    clip: true
    implicitHeight: label.height
    readonly property real overflow: Math.max(0, label.width - width)
    readonly property bool scrolling: overflow > 0

    BarText { id: label; text: root.text; color: root.color; font.pixelSize: root.pixelSize; font.weight: root.weight; x: 0 }
    BarText { visible: root.scrolling; text: root.text; color: root.color; font.pixelSize: root.pixelSize; font.weight: root.weight; x: label.x + label.width + root.gap }

    SequentialAnimation {
        running: root.scrolling && root.visible
        loops: Animation.Infinite
        PauseAnimation { duration: root.rest }
        NumberAnimation { target: label; property: "x"; from: 0; to: -(label.width + root.gap); duration: Math.max(1, (label.width + root.gap) / root.speed * 1000); easing.type: Easing.Linear }
    }
    // A new track starts from the left again.
    onTextChanged: label.x = 0
    onScrollingChanged: if (!scrolling) label.x = 0

    // The faded ends: a mask that is opaque in the middle and clear at both edges.
    layer.enabled: root.scrolling
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: fadeMask
        maskThresholdMin: 0.0
        maskSpreadAtMin: 0.0
    }
    Item {
        id: fadeMask
        visible: false
        layer.enabled: true
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#00000000" }
                GradientStop { position: Math.min(0.4, root.fade / Math.max(1, root.width)); color: "#ff000000" }
                GradientStop { position: Math.max(0.6, 1 - root.fade / Math.max(1, root.width)); color: "#ff000000" }
                GradientStop { position: 1; color: "#00000000" }
            }
        }
    }
}
