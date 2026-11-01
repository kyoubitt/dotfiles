import QtQuick
import qs.modules.common

// A collapsible section: icon, title and a one-line summary in the header; the body slides open.
// Open or closed is remembered in `bars.sidebars.expanded`.
Item {
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

    // The body's own implicit height, not its bounding box: that one depends on this item's size.
    readonly property real bodyHeight: bodyHolder.children.length > 0 ? (bodyHolder.children[0].implicitHeight ?? 0) : 0
    implicitHeight: header.height + (open && !collapsed ? bodyHeight + 14 : 0)
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    function toggle(): void {
        const next = open ? expandedList.filter(k => k !== name) : expandedList.concat([name])
        Config.options.bars.sidebars.expanded = next
    }

    Rectangle {
        id: header
        width: parent.width; height: 48; radius: 16
        color: hdAreaHv.hovered ? BarStyle.plateHover : "transparent"
        border.width: 1; border.color: BarStyle.border
        Behavior on color { ColorAnimation { duration: 100 } }
        BarIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: root.icon; size: 18; fill: 1; color: root.open ? BarStyle.accent : BarStyle.subtext }
        Column {
            x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44 - 40
            BarText { text: root.title; font.weight: Font.DemiBold; width: parent.width; elide: Text.ElideRight }
            BarText { visible: !root.open && root.summary.length > 0; text: root.summary; font.pixelSize: 11; color: BarStyle.subtext; width: parent.width; elide: Text.ElideRight }
        }
        BarIcon { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; name: "expand_more"; size: 18; color: BarStyle.subtext; rotation: root.open ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } } }
        MouseArea { id: hdArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggle() }
        HoverHandler { id: hdAreaHv }
    }
    Item {
        id: bodyHolder
        y: header.height + 14
        width: parent.width
        opacity: root.open && !root.collapsed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
