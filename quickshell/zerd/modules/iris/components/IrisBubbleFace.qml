import QtQuick

// Floating-piece face: pieces are not ported, so this is an inert box.
Item {
    property string screenName: ""
    property string kind: ""
    property bool plated: false
    property bool hovered: false
    property bool pressed: false
    signal wheel(var event)
    visible: false
}
