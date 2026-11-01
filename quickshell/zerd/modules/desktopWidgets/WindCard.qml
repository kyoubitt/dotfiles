import QtQuick
import qs.modules.iris.widgets
import qs.modules.iris.style
import qs.services

// Wind speed and direction, in the weather card's style: a header glyph,
// a big figure with its unit, and a compass dial pointing where the wind blows from.
IrisWidgetFace {
    id: root

    readonly property string raw: String(Weather.data.wind ?? "0 km/h")
    readonly property string speed: raw.split(" ")[0]
    readonly property string unit: raw.split(" ").slice(1).join(" ")
    readonly property string dir: String(Weather.data.windDir ?? "N")
    readonly property var points: ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
    readonly property real angle: Math.max(0, points.indexOf(dir)) * 22.5

    FaceHeader {
        face: root
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.dp(20)
        glyph: "air"
        text: "Wind"
        tint: IrisStyle.identity.sky
    }

    Item {
        id: dial
        width: root.dp(64); height: width
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 2; border.color: root.hairline }
        Item {
            anchors.fill: parent
            rotation: root.angle + 180
            Rectangle {
                width: root.dp(4); height: parent.height * 0.42; radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.08
                color: IrisStyle.identity.sky
            }
        }
        FaceText { face: root; anchors.centerIn: parent; text: root.dir; size: 12; weight: Font.DemiBold; color: root.ink }
    }

    Column {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: 0
        FaceText { face: root; text: root.speed; size: 44; weight: Font.DemiBold; color: root.ink }
        FaceText { face: root; text: root.unit; size: 14; color: root.inkSecondary }
    }
}
