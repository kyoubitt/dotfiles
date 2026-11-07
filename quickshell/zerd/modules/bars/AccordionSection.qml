import QtQuick
import qs.modules.common

// A collapsible section on a card (the same surface as BarCard): icon tile, title and a one-line summary in the header,
// the body opening below it with the panel's emphasized easing. Open or closed is remembered in `bars.sidebars.expanded`.
Rectangle {
    id: root

    property string name: ""
    property string icon: ""
    property string title: ""
    property string summary: ""
    // Folded to the header while sections are being dragged.
    property bool collapsed: false
    default property alias body: bodyHolder.data
    readonly property var expandedList: Config.options?.bars?.sidebars?.expanded ?? []
    readonly property bool open: expandedList.includes(name)
    readonly property bool expanded: open && !collapsed
    readonly property int headHeight: 52

    // The body's own implicit height, not its bounding box: that one depends on this item's size. A body that only sets
    // a height (a list) has no implicit one, so its height stands in.
    readonly property real bodyHeight: {
        const c = bodyHolder.children.length > 0 ? bodyHolder.children[0] : null
        if (!c) return 0
        return (c.implicitHeight ?? 0) > 0 ? c.implicitHeight : (c.height ?? 0)
    }
    implicitHeight: headHeight + (expanded ? bodyHeight + 12 : 0)
    radius: BarStyle.radiusMedium
    color: BarStyle.card
    border.width: 1
    border.color: BarStyle.edge
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: BarStyle.motionNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: BarStyle.easeEmphasized } }

    function toggle(): void {
        const next = open ? expandedList.filter(k => k !== name) : expandedList.concat([name])
        Config.options.bars.sidebars.expanded = next
    }

    BarButton {
        id: header
        tone: "plain"
        width: parent.width; height: root.headHeight; radius: root.radius
        onTapped: root.toggle()
        Rectangle {
            id: tile
            x: 12; anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: 10
            color: root.open ? BarStyle.accentContainer : BarStyle.cardHigh
            Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }
            BarIcon { anchors.centerIn: parent; name: root.icon; size: 18; fill: 1; color: root.open ? BarStyle.accent : BarStyle.subtext }
        }
        Column {
            x: tile.x + tile.width + 12; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 70
            BarText { text: root.title; font.weight: Font.DemiBold; width: parent.width; elide: Text.ElideRight }
            BarText { visible: !root.open && root.summary.length > 0; text: root.summary; font.pixelSize: 11; color: BarStyle.subtext; width: parent.width; elide: Text.ElideRight }
        }
        BarIcon {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            name: "expand_more"; size: 20; color: BarStyle.subtext
            rotation: root.open ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: BarStyle.motionNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: BarStyle.easeEmphasized } }
        }
    }
    Item {
        id: bodyHolder
        x: 8; y: root.headHeight + 2
        width: parent.width - 16
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: BarStyle.motionFast } }
    }
}
