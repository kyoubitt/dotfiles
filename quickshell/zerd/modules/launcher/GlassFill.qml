import QtQuick

// The original draws liquid glass here; this shell keeps flat Material surfaces, so it never takes over.
Item {
    property bool active: false
    property bool allowed: true
    property bool forceOpaque: false
    property bool forceClear: false
    property real radius: 0
    property color tintColor: "transparent"
    property real tintAmount: 0
    property real tintStrength: 1
    property real press: 0
}
