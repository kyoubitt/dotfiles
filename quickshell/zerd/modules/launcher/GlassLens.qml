import QtQuick

// Stand-in for the original's moving glass lens: inactive, the rows draw their own highlight.
Item {
    property bool glassActive: false
    property bool instant: false
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0
    property real radius: 0
    property real shadow: 0
    property bool forceOpaque: false
    property color tintColor: "transparent"
    property real tintAmount: 0
    property real tintStrength: 1
    property real press: 0
    property real restPress: 0
    property real magnify: 0
    property int fastDuration: 0
    property int slowDuration: 0
    property bool followBackdropHover: false
}
