import QtQuick
import qs.services

// Full weather card: now, high/low, details, next hours, three days, sun.
Column {
    id: root

    readonly property var d: Weather.data
    spacing: 14

    function minutes(t: string): int {
        const m = /(\d+):(\d+)\s*(AM|PM)?/i.exec(t ?? "")
        if (!m) return -1
        let h = parseInt(m[1]) % 12
        if (/pm/i.test(m[3] ?? "") || (!m[3] && parseInt(m[1]) >= 12)) h += 12
        return h * 60 + parseInt(m[2])
    }
    readonly property int nowMin: new Date().getHours() * 60 + new Date().getMinutes()
    readonly property real sunProgress: {
        const a = minutes(d.sunrise), b = minutes(d.sunset)
        return a < 0 || b <= a ? 0 : Math.max(0, Math.min(1, (nowMin - a) / (b - a)))
    }

    Row {
        spacing: 14
        BarIcon { name: BarStyle.weatherIcon(root.d.wCode); size: 52; fill: 1; color: BarStyle.accent }
        Column {
            spacing: 0
            BarText { text: root.d.temp; font.pixelSize: 30; font.weight: Font.DemiBold }
            BarText { text: BarStyle.weatherText(root.d.wCode) + "  ·  feels " + root.d.tempFeelsLike; color: BarStyle.subtext }
        }
        Item { width: 20; height: 1 }
        Column {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            BarText { text: root.d.city; font.weight: Font.DemiBold; elide: Text.ElideRight; width: Math.min(implicitWidth, 110) }
            Row {
                spacing: 8
                BarText { text: "↑ " + (root.d.high ?? "--"); color: BarStyle.text }
                BarText { text: "↓ " + (root.d.low ?? "--"); color: BarStyle.subtext }
            }
        }
    }

    Grid {
        columns: 3
        spacing: 6
        component Chip: Rectangle {
            id: chip
            property string icon
            property string value
            property string label
            width: 106; height: 52; radius: BarStyle.radiusSmall
            color: BarStyle.card
            Column {
                anchors.centerIn: parent
                spacing: 0
                Row {
                    spacing: 5; anchors.horizontalCenter: parent.horizontalCenter
                    BarIcon { name: chip.icon; size: 14; color: BarStyle.accent }
                    BarText { text: chip.value; font.pixelSize: 12; font.weight: Font.DemiBold }
                }
                BarText { anchors.horizontalCenter: parent.horizontalCenter; text: chip.label; font.pixelSize: 11; color: BarStyle.subtext }
            }
        }
        Chip { icon: "humidity_percentage"; value: root.d.humidity; label: "Humidity" }
        Chip { icon: "air"; value: root.d.wind + " " + root.d.windDir; label: "Wind" }
        Chip { icon: "wb_sunny"; value: root.d.uv; label: "UV index" }
        Chip { icon: "water_drop"; value: root.d.precip; label: "Precipitation" }
        Chip { icon: "speed"; value: root.d.press; label: "Pressure" }
        Chip { icon: "visibility"; value: root.d.visib; label: "Visibility" }
    }

    Row {
        visible: (root.d.hourly?.length ?? 0) > 0
        spacing: 0
        Repeater {
            model: root.d.hourly ?? []
            delegate: Column {
                required property var modelData
                width: 322 / 8
                spacing: 3
                BarText { anchors.horizontalCenter: parent.horizontalCenter; text: (modelData.hour < 10 ? "0" : "") + modelData.hour; font.pixelSize: 11; color: BarStyle.subtext }
                BarIcon { anchors.horizontalCenter: parent.horizontalCenter; name: BarStyle.weatherIcon(modelData.code); size: 20; fill: 1 }
                BarText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.temp + "°"; font.pixelSize: 12; font.weight: Font.DemiBold }
            }
        }
    }

    Column {
        visible: (root.d.daily?.length ?? 0) > 0
        spacing: 4
        Repeater {
            model: root.d.daily ?? []
            delegate: Row {
                required property var modelData
                required property int index
                spacing: 10
                BarText { width: 72; text: index === 0 ? "Today" : Qt.formatDate(new Date(modelData.date + "T12:00:00"), "dddd").slice(0, 3); color: index === 0 ? BarStyle.text : BarStyle.subtext }
                BarIcon { name: BarStyle.weatherIcon(modelData.code); size: 18; fill: 1; color: BarStyle.accent }
                BarText { width: 36; text: modelData.low + "°"; horizontalAlignment: Text.AlignRight; color: BarStyle.subtext }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 100; height: 4; radius: 2; color: BarStyle.border
                    Rectangle { width: parent.width * 0.6; x: parent.width * 0.2; height: 4; radius: 2; color: BarStyle.accent }
                }
                BarText { width: 36; text: modelData.high + "°" }
            }
        }
    }

    Row {
        spacing: 8
        BarIcon { name: "wb_twilight"; size: 16; color: BarStyle.subtext }
        BarText { text: root.d.sunrise; font.pixelSize: 12 }
        Item {
            width: 322 - 2 * 70; height: 18
            Rectangle { y: 7; width: parent.width; height: 4; radius: 2; color: BarStyle.border }
            Rectangle { y: 7; width: parent.width * root.sunProgress; height: 4; radius: 2; color: BarStyle.accent }
            Rectangle { x: Math.round(parent.width * root.sunProgress - 5); y: 4; width: 10; height: 10; radius: 5; color: BarStyle.accent; visible: root.sunProgress > 0 && root.sunProgress < 1 }
        }
        BarText { text: root.d.sunset; font.pixelSize: 12 }
        BarIcon { name: "bedtime"; size: 16; color: BarStyle.subtext }
    }

    Row {
        spacing: 8
        BarText { text: Weather.updatedLabel.length > 0 ? "Updated " + Weather.updatedLabel : ""; font.pixelSize: 11; color: BarStyle.subtext }
        Item { width: 322 - 190; height: 1 }
        BarIcon {
            name: "refresh"; size: 16; color: BarStyle.subtext
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Weather.getData() }
        }
    }
}
