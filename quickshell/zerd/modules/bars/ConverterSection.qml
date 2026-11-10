import QtQuick
import Quickshell

// Offline unit converter. Every unit is `base = value * f + o`, which covers temperature too.
Column {
    id: root

    readonly property var cats: [
        { id: "Length", units: [{ n: "mm", f: 0.001, o: 0 }, { n: "cm", f: 0.01, o: 0 }, { n: "m", f: 1, o: 0 }, { n: "km", f: 1000, o: 0 },
            { n: "in", f: 0.0254, o: 0 }, { n: "ft", f: 0.3048, o: 0 }, { n: "yd", f: 0.9144, o: 0 }, { n: "mi", f: 1609.344, o: 0 }] },
        { id: "Mass", units: [{ n: "g", f: 0.001, o: 0 }, { n: "kg", f: 1, o: 0 }, { n: "oz", f: 0.0283495, o: 0 }, { n: "lb", f: 0.45359237, o: 0 }] },
        { id: "Temp", units: [{ n: "°C", f: 1, o: 0 }, { n: "°F", f: 5 / 9, o: -160 / 9 }, { n: "K", f: 1, o: -273.15 }] },
        { id: "Speed", units: [{ n: "m/s", f: 1, o: 0 }, { n: "km/h", f: 1 / 3.6, o: 0 }, { n: "mph", f: 0.44704, o: 0 }, { n: "kn", f: 0.514444, o: 0 }] },
        { id: "Data", units: [{ n: "B", f: 1, o: 0 }, { n: "KB", f: 1024, o: 0 }, { n: "MB", f: 1048576, o: 0 }, { n: "GB", f: 1073741824, o: 0 }, { n: "TB", f: 1099511627776, o: 0 }] },
        { id: "Volume", units: [{ n: "ml", f: 0.001, o: 0 }, { n: "L", f: 1, o: 0 }, { n: "cup", f: 0.236588, o: 0 }, { n: "gal", f: 3.78541, o: 0 }] }
    ]
    property int cat: 0
    property int from: 0
    property int to: 1
    readonly property var units: root.cats[root.cat].units
    readonly property real value: parseFloat(input.text.replace(",", "."))
    readonly property string result: {
        if (isNaN(root.value)) return "–"
        const u = root.units, a = u[Math.min(root.from, u.length - 1)], b = u[Math.min(root.to, u.length - 1)]
        const base = root.value * a.f + a.o
        const r = (base - b.o) / b.f
        return String(Number(r.toPrecision(7)))
    }
    spacing: 10

    component Chip: Rectangle {
        id: chip
        property string label
        property bool on: false
        signal tapped()
        width: chipText.implicitWidth + 18; height: 26; radius: 17
        color: on ? BarStyle.accent : (chipArea.pressed ? BarStyle.border : BarStyle.cardHigh)
        Behavior on color { ColorAnimation { duration: 100 } }
        BarText { id: chipText; anchors.centerIn: parent; text: chip.label; font.pixelSize: 12; color: chip.on ? BarStyle.onAccent : BarStyle.text }
        MouseArea { id: chipArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: chip.tapped() }
    }

    Flow {
        width: parent.width; spacing: 6
        Repeater {
            model: root.cats
            delegate: Chip {
                required property var modelData
                required property int index
                label: modelData.id; on: root.cat === index
                onTapped: { root.cat = index; root.from = 0; root.to = 1 }
            }
        }
    }

    Rectangle {
        width: parent.width; height: 40; radius: 23
        color: BarStyle.cardHigh
        border.width: 1; border.color: input.activeFocus ? BarStyle.accent : BarStyle.border
        TextInput {
            id: input
            x: 16; width: parent.width - 32; height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            color: BarStyle.text
            font.pixelSize: 16
            text: "1"
            clip: true
            selectByMouse: true
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
    }
    Flow {
        width: parent.width; spacing: 6
        Repeater {
            model: root.units
            delegate: Chip { required property var modelData; required property int index; label: modelData.n; on: root.from === index; onTapped: root.from = index }
        }
    }

    Row {
        spacing: 8
        BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_downward"; size: 16; color: BarStyle.subtext }
        BarText { anchors.verticalCenter: parent.verticalCenter; text: "to"; color: BarStyle.subtext; font.pixelSize: 12 }
    }
    Flow {
        width: parent.width; spacing: 6
        Repeater {
            model: root.units
            delegate: Chip { required property var modelData; required property int index; label: modelData.n; on: root.to === index; onTapped: root.to = index }
        }
    }

    Rectangle {
        width: parent.width; height: 48; radius: 30
        color: resultArea.pressed ? BarStyle.border : BarStyle.cardHigh
        Behavior on color { ColorAnimation { duration: 100 } }
        BarText {
            anchors.verticalCenter: parent.verticalCenter
            x: 18; width: parent.width - 36
            elide: Text.ElideRight
            text: root.result + "  " + root.units[Math.min(root.to, root.units.length - 1)].n
            font.pixelSize: 20; font.weight: Font.DemiBold
        }
        MouseArea { id: resultArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["wl-copy", root.result]) }
    }
}
