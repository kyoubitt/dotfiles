import QtQuick
import Quickshell.Widgets

// A button surface the way iNiR does it: hovering lays 8 % of the text colour over it, pressing 12 % plus a ripple that
// grows from the click and a small press scale. Tones: plain (no fill), tonal (a card), filled (the accent), outlined.
Item {
    id: root

    property string tone: "tonal"
    property bool toggled: false
    property real radius: BarStyle.radiusSmall
    property bool rippleEnabled: true
    readonly property bool hovered: hov.hovered
    readonly property bool pressed: ma.pressed
    default property alias content: slot.data
    signal tapped()
    signal secondary()
    signal middle()

    readonly property bool onAccentFill: tone === "filled" || (toggled && tone === "filled")
    readonly property color fill: tone === "filled" ? BarStyle.accent
        : tone === "plain" || tone === "outlined" ? (toggled ? BarStyle.accentContainer : "transparent")
        : (toggled ? BarStyle.accentContainer : BarStyle.card)
    // the colour of what sits on the button
    readonly property color ink: tone === "filled" ? BarStyle.onAccent : (toggled ? BarStyle.onAccentContainer : BarStyle.text)
    readonly property color inkSoft: tone === "filled" ? BarStyle.onAccent : (toggled ? BarStyle.onAccentContainer : BarStyle.subtext)

    scale: pressed ? Math.max(0.94, Math.min(0.995, 1 - 2 / Math.max(width, height))) : 1
    Behavior on scale { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutCubic } }

    Rectangle {
        id: face
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        border.width: root.tone === "outlined" ? 1 : 0
        border.color: BarStyle.border
        Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }
    }
    // the state layer and the ripple, clipped to the button's shape
    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, root.pressed ? 0.12 : root.hovered ? 0.08 : 0)
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            id: ripple
            property real r: 0
            x: ma.rx - r; y: ma.ry - r
            width: 2 * r; height: 2 * r; radius: r
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16)
            opacity: 0
            ParallelAnimation {
                id: rippleAnim
                NumberAnimation { target: ripple; property: "r"; from: 0; to: Math.sqrt(root.width * root.width + root.height * root.height); duration: 550; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    NumberAnimation { target: ripple; property: "opacity"; from: 1; to: 1; duration: 150 }
                    NumberAnimation { target: ripple; property: "opacity"; to: 0; duration: 450 }
                }
            }
        }
    }
    Item { id: slot; anchors.fill: parent }

    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    MouseArea {
        id: ma
        property real rx: 0
        property real ry: 0
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => { rx = mouse.x; ry = mouse.y; if (root.rippleEnabled) rippleAnim.restart() }
        onClicked: mouse => { if (mouse.button === Qt.RightButton) root.secondary(); else if (mouse.button === Qt.MiddleButton) root.middle(); else root.tapped() }
    }
}
