import QtQuick
import qs.modules.common
import qs.services

// Left info capsule: cpu / memory / gpu, then the weather. Each half opens its popup.
BarPill {
    id: root

    readonly property var opts: Config.options?.bars?.top ?? ({})
    readonly property bool cpuOn: opts.showCpu ?? true
    readonly property bool memOn: opts.showMemory ?? true
    readonly property bool gpuOn: (opts.showGpu ?? true) && ResourceUsage.gpuAvailable
    readonly property bool weatherOn: opts.showWeather ?? true
    readonly property bool sysShown: cpuOn || memOn || gpuOn
    readonly property bool weatherShown: weatherOn && Weather.data.temp !== "--°C" && Weather.data.temp !== "--°F"
    visible: sysShown || weatherShown

    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

    component Stat: Row {
        property string icon
        property real value
        spacing: 4
        BarIcon { name: parent.icon; size: 16; color: BarStyle.subtext }
        BarText { text: Math.round(parent.value * 100) + "%"; font.pixelSize: 12 }
    }

    Item {
        id: sysItem
        visible: root.sysShown
        implicitWidth: sys.implicitWidth
        implicitHeight: 24
        Row {
            id: sys
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Stat { visible: root.cpuOn; icon: "memory"; value: ResourceUsage.cpuUsage }
            Stat { visible: root.memOn; icon: "developer_board"; value: ResourceUsage.memoryUsedPercentage }
            Stat { visible: root.gpuOn; icon: "videogame_asset"; value: ResourceUsage.gpuUsage }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: root.openPopup("system") }
        BarTip { text: "System" }
    }
    Rectangle { visible: root.weatherShown && root.sysShown; width: 1; height: 14; color: BarStyle.border }
    Item {
        id: weather
        visible: root.weatherShown
        implicitWidth: wRow.implicitWidth
        implicitHeight: 24
        Row {
            id: wRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            BarIcon { anchors.verticalCenter: parent.verticalCenter; name: BarStyle.weatherIcon(Weather.data.wCode); size: 18; fill: 1; color: BarStyle.weatherColor(Weather.data.wCode) }
            BarText { anchors.verticalCenter: parent.verticalCenter; text: Weather.data.temp; font.pixelSize: 13; font.weight: Font.DemiBold }
            // Today's high and low, each with its own arrow.
            Row {
                visible: Weather.data.high !== undefined
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Row {
                    spacing: 1
                    BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_upward"; size: 11; color: BarStyle.warm }
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: String(Weather.data.high).replace(/[^0-9-]/g, "") + "°"; font.pixelSize: 11; color: BarStyle.subtext }
                }
                Row {
                    spacing: 1
                    BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_downward"; size: 11; color: BarStyle.cool }
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: String(Weather.data.low).replace(/[^0-9-]/g, "") + "°"; font.pixelSize: 11; color: BarStyle.subtext }
                }
            }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: root.openPopup("weather") }
        BarTip { text: BarStyle.weatherText(Weather.data.wCode) + "  " + Weather.data.city }
    }
}
