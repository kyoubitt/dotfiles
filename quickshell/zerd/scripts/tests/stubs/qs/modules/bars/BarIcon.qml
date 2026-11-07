import QtQuick

Item {
    property string name: ""
    property real size: 18
    property real fill: 0
    property color color: "white"
    implicitWidth: Math.round(size)
    implicitHeight: Math.round(size)
}
