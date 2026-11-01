import QtQuick

// A small icon button for the screenshot tools: lit when `on`, dimmed when disabled, named on hover.
Rectangle {
    id: root

    property string icon
    property string tip
    property bool on: false
    property bool enabledBtn: true
    signal tapped()

    width: 38; height: 36; radius: 10
    opacity: enabledBtn ? 1 : 0.35
    color: area.pressed ? BarStyle.border : (on ? BarStyle.plateHover : (hover.hovered && enabledBtn ? Qt.rgba(BarStyle.plateHover.r, BarStyle.plateHover.g, BarStyle.plateHover.b, 0.6) : "transparent"))
    Behavior on color { ColorAnimation { duration: 80 } }
    BarIcon { anchors.centerIn: parent; name: root.icon; size: 20; color: root.on ? BarStyle.accent : BarStyle.text }
    MouseArea { id: area; anchors.fill: parent; enabled: root.enabledBtn; cursorShape: Qt.PointingHandCursor; onClicked: root.tapped() }
    HoverHandler { id: hover }
    BarTip { text: root.tip; external: hover.hovered && root.tip.length > 0 }
}
