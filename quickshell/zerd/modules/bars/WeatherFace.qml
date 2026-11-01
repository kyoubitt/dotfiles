import QtQuick
import qs.services

BarPill {
    id: root

    interactive: true
    tip: BarStyle.weatherText(Weather.data.wCode) + "  " + Weather.data.city
    onClicked: openPopup("weather")
    visible: Weather.data.temp !== "--°C" && Weather.data.temp !== "--°F"
    BarIcon { name: BarStyle.weatherIcon(Weather.data.wCode); fill: 1; color: BarStyle.accent }
    BarText { visible: !root.vertical; text: Weather.data.temp }
    BarText { visible: !root.vertical && Weather.data.high !== undefined; text: Weather.data.high + " / " + Weather.data.low; color: BarStyle.subtext; font.pixelSize: 12 }
}
