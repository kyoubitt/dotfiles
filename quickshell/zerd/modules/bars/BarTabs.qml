import QtQuick

// A row of tabs with one accent pill behind the chosen one. When the choice changes the pill stretches over to the new
// tab: the edge that is heading there moves first (the stretch of the workspace pills, after ilyamiro's rice,
// serpantinum, AGPL-3.0). `model` is a list of { icon, text }.
Item {
    id: root

    property var model: []
    property int current: 0
    property int tabHeight: 34
    signal picked(int index)

    readonly property real cell: model.length > 0 ? width / model.length : 0
    implicitWidth: 320
    implicitHeight: tabHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: BarStyle.card
        border.width: 1
        border.color: BarStyle.edge
    }

    // the pill: its two edges are animated by hand so they can take different times
    property real edgeL: 3
    property real edgeR: 3
    property int last: 0
    readonly property real goalL: current * cell + 3
    readonly property real goalR: (current + 1) * cell - 3
    NumberAnimation { id: animL; target: root; property: "edgeL"; easing.type: Easing.OutCubic }
    NumberAnimation { id: animR; target: root; property: "edgeR"; easing.type: Easing.OutCubic }
    function snap(): void {
        animL.stop(); animR.stop()
        root.edgeL = root.goalL
        root.edgeR = root.goalR
        root.last = root.current
    }
    function go(): void {
        if (root.cell <= 0) return
        const forward = root.current >= root.last
        animL.stop(); animR.stop()
        animL.duration = forward ? 320 : 200
        animR.duration = forward ? 200 : 320
        animL.to = root.goalL
        animR.to = root.goalR
        animL.start(); animR.start()
        root.last = root.current
    }
    onCurrentChanged: root.go()
    onCellChanged: if (!animL.running) root.snap()
    Component.onCompleted: root.snap()

    Rectangle {
        x: root.edgeL
        y: 3
        width: Math.max(0, root.edgeR - root.edgeL)
        height: root.height - 6
        radius: height / 2
        color: BarStyle.accent
        antialiasing: true
    }

    Repeater {
        model: root.model
        delegate: Item {
            id: tab
            required property var modelData
            required property int index
            readonly property bool on: index === root.current
            x: index * root.cell
            width: root.cell
            height: root.height

            BarHoverFill {
                x: 3; y: 3; width: parent.width - 6; height: parent.height - 6
                radius: height / 2
                hovered: tabHover.hovered && !tab.on
                pressed: tabMouse.pressed && !tab.on
            }
            Row {
                x: Math.round((tab.width - width) / 2)
                y: Math.round((tab.height - height) / 2)
                spacing: 6
                BarIcon {
                    visible: (tab.modelData.icon ?? "").length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    name: tab.modelData.icon ?? ""
                    size: 18
                    fill: tab.on ? 1 : 0
                    color: tab.on ? BarStyle.onAccent : BarStyle.subtext
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.modelData.text ?? ""
                    font.pixelSize: 12
                    font.weight: tab.on ? Font.DemiBold : Font.Medium
                    color: tab.on ? BarStyle.onAccent : BarStyle.text
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }
            HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
            MouseArea { id: tabMouse; anchors.fill: parent; onClicked: root.picked(tab.index) }
        }
    }
}
