import QtQuick

// The round icon button of the side panels' headers: pin, close, settings, lock, session. Ripple and state layers from
// BarButton, a tooltip, and the icon lit in the accent while `toggled`.
BarButton {
    id: root

    property string icon: ""
    property string tip: ""
    property int size: 36
    property int iconSize: 18

    tone: "tonal"
    width: size; height: size
    // round at rest, squarer under the pointer, tight while pressed: the shape answers the touch
    radius: pressed ? size * 0.28 : (hovered ? size * 0.36 : size / 2)
    Behavior on radius { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutCubic } }

    BarIcon { anchors.centerIn: parent; name: root.icon; size: root.iconSize; fill: root.toggled ? 1 : 0; color: root.toggled ? BarStyle.accent : root.ink }
    BarTip { text: root.tip; external: root.hovered }
}
