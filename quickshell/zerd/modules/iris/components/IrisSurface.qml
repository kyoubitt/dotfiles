import QtQuick
import qs.modules.iris.style

Rectangle {
    id: root

    property bool raised: false
    property bool quiet: false
    property bool notchTop: false
    property bool notchBottom: false

    color: IrisStyle.surface
    antialiasing: true
    topLeftRadius: root.notchTop ? 0 : radius
    topRightRadius: root.notchTop ? 0 : radius
    bottomLeftRadius: root.notchBottom ? 0 : radius
    bottomRightRadius: root.notchBottom ? 0 : radius
    border.width: 1
    border.color: IrisStyle.hairlineStrong
}
