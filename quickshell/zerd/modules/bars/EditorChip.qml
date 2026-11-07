import QtQuick

// A pill button for the editors: an optional icon and a label. Outlined and quiet by default, lit (tonal accent) while
// `toggled`, the accent fill when `primary`. The width follows the label, so rows of them wrap cleanly in a Flow.
BarButton {
    id: chip

    property string icon: ""
    property string label: ""
    property bool primary: false
    property bool dim: false
    property int size: 34
    property int iconSize: 16

    tone: primary ? "filled" : "outlined"
    height: size
    radius: height / 2
    width: row.implicitWidth + (icon.length > 0 ? 26 : 28)
    opacity: dim ? 0.4 : 1
    enabled: !dim

    Row {
        id: row
        x: chip.icon.length > 0 ? 12 : 14
        height: parent.height
        spacing: 7
        BarIcon { visible: chip.icon.length > 0; anchors.verticalCenter: parent.verticalCenter; name: chip.icon; size: chip.iconSize; fill: chip.toggled ? 1 : 0; color: chip.toggled || chip.primary ? chip.ink : chip.inkSoft }
        BarText { anchors.verticalCenter: parent.verticalCenter; text: chip.label; font.pixelSize: 13; font.weight: chip.primary ? Font.DemiBold : Font.Medium; color: chip.ink }
    }
}
