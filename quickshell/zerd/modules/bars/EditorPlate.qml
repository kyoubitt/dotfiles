import QtQuick

// The one surface every editor sits on: the bar editor's boxes and tool strip, the widget board's picker and tool
// strip, the notification rules list. A titled plate takes its height from what is inside it (a Flow wraps first,
// the plate follows), so nothing ever overlaps or spills out; `pill` is the rounded tool strip, `target` lights a
// drop zone while something is held over it.
Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    property string hint: ""
    property bool target: false
    property bool pill: false
    // A strip as wide as its content (tool strips); a box fills what its parent gives it.
    property bool fitWidth: false
    property real pad: pill ? 8 : 16
    // Presses stop on the plate, so a drag surface behind it never starts; a drop zone that is itself dragged from turns it off.
    property bool swallow: true
    default property alias content: body.data

    readonly property bool titled: !pill && (title.length > 0 || hint.length > 0)
    readonly property real headHeight: titled ? 22 : 0
    readonly property real gap: titled ? 10 : 0

    implicitWidth: fitWidth ? body.childrenRect.width + 2 * pad : 0
    implicitHeight: 2 * pad + headHeight + gap + body.height
    height: implicitHeight
    radius: pill ? height / 2 : BarStyle.radiusLarge
    color: target ? Qt.tint(BarStyle.surface, Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.16)) : BarStyle.surface
    border.width: target ? 2 : 1
    border.color: target ? BarStyle.accent : BarStyle.edge
    Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }

    MouseArea { anchors.fill: parent; enabled: root.swallow; acceptedButtons: Qt.AllButtons }
    Row {
        visible: root.titled
        x: root.pad + 2; y: root.pad
        height: 22
        spacing: 8
        BarIcon { visible: root.icon.length > 0; anchors.verticalCenter: parent.verticalCenter; name: root.icon; size: 16; fill: 1; color: BarStyle.accent }
        BarText { anchors.verticalCenter: parent.verticalCenter; text: root.title; font.pixelSize: 12; font.weight: Font.DemiBold; color: BarStyle.subtext }
    }
    BarText {
        visible: root.titled && root.hint.length > 0
        anchors.right: parent.right; anchors.rightMargin: root.pad + 2
        y: root.pad + Math.round((22 - height) / 2)
        text: root.hint; font.pixelSize: 11; color: BarStyle.subtext
    }
    Item {
        id: body
        x: root.pad
        y: root.pad + root.headHeight + root.gap
        width: root.width - 2 * root.pad
        height: childrenRect.height
    }
}
