import QtQuick
import qs.modules.common
import qs.services

// Left info capsule: cpu / memory / gpu, then the weather. Each half is a button with the shared liquid hover and
// opens its popup.
BarPill {
    id: root
    strip: true

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
        BarIcon { anchors.verticalCenter: parent.verticalCenter; name: parent.icon; color: BarStyle.subtext }
        BarText { anchors.verticalCenter: parent.verticalCenter; text: Math.round(parent.value * 100) + "%"; font.pixelSize: 12 }
    }

    BarCell {
        visible: root.sysShown
        tip: "System"
        padding: 10
        onTapped: root.openPopup("system")
        Row {
            spacing: 10
            Stat { visible: root.cpuOn; icon: "memory"; value: ResourceUsage.cpuUsage }
            Stat { visible: root.memOn; icon: "developer_board"; value: ResourceUsage.memoryUsedPercentage }
            Stat { visible: root.gpuOn; icon: "videogame_asset"; value: ResourceUsage.gpuUsage }
        }
    }
    BarCell {
        visible: root.weatherShown
        tip: BarStyle.weatherText(Weather.data.wCode) + "  " + Weather.data.city
        padding: 10
        onTapped: root.openPopup("weather")
        Row {
            spacing: 6
            BarIcon { anchors.verticalCenter: parent.verticalCenter; name: BarStyle.weatherIcon(Weather.data.wCode); fill: 1; color: BarStyle.weatherColor(Weather.data.wCode) }
            BarText { anchors.verticalCenter: parent.verticalCenter; text: Weather.data.temp; font.weight: Font.DemiBold }
            // Today's high and low, each with its own arrow.
            Row {
                visible: Weather.data.high !== undefined
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Row {
                    spacing: 1
                    BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_upward"; size: 12; color: BarStyle.warm }
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: String(Weather.data.high).replace(/[^0-9-]/g, "") + "°"; font.pixelSize: 11; color: BarStyle.subtext }
                }
                Row {
                    spacing: 1
                    BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_downward"; size: 12; color: BarStyle.cool }
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: String(Weather.data.low).replace(/[^0-9-]/g, "") + "°"; font.pixelSize: 11; color: BarStyle.subtext }
                }
            }
        }
    }
}
