import QtQuick

// The hover and press layer of a list row: 8 % of the text colour while hovered, 12 % while pressed.
Rectangle {
    property bool hovered: false
    property bool pressed: false
    radius: BarStyle.radiusSmall
    color: Qt.rgba(BarStyle.text.r, BarStyle.text.g, BarStyle.text.b, pressed ? 0.12 : hovered ? 0.08 : 0)
    Behavior on color { ColorAnimation { duration: 120 } }
}
