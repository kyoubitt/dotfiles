import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services

// No location/city labels anywhere by design. A small two-step fetch of
// its own (IP geolocation, then Open-Meteo) - independent of any other
// weather service in this config.
Item {
    id: root
    // Fixed to the card's actual available content width (~284px, same
    // figure WCalendarCard.qml targets) rather than shrink-wrapping to
    // row's natural content size - shrink-wrapping is what left a blank
    // strip between the metrics column and the sun glyph, since nothing
    // was ever wider than row's own unstretched content to push the glyph
    // out to the true right edge.
    implicitWidth: 284
    implicitHeight: row.implicitHeight

    property real tempF: 0
    property real feelsLikeF: 0
    property real humidity: 0
    property real windMph: 0
    property string sunrise: ""
    property string sunset: ""
    property string windDir: "-"
    property real windDirDeg: 0
    property int weatherCode: 0
    property bool haveData: false

    readonly property var compassPoints: ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    function degreesToCompass(deg) {
        const idx = Math.round(((deg % 360) / 45)) % 8
        return compassPoints[idx]
    }

    function weatherGlyph(code) {
        if (code === 0) return "clear_day"
        if (code <= 3) return "partly_cloudy_day"
        if (code <= 48) return "foggy"
        if (code <= 67) return "rainy"
        if (code <= 77) return "weather_snowy"
        if (code <= 82) return "rainy"
        if (code <= 99) return "thunderstorm"
        return "cloud"
    }

    Process {
        id: geoProc
        command: ["curl", "-s", "http://ip-api.com/json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const geo = JSON.parse(text)
                    if (geo.lat !== undefined && geo.lon !== undefined) {
                        weatherProc.command = [
                            "curl", "-s",
                            `https://api.open-meteo.com/v1/forecast?latitude=${geo.lat}&longitude=${geo.lon}` +
                            `&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,wind_direction_10m,weather_code` +
                            `&temperature_unit=fahrenheit&wind_speed_unit=mph` +
                            `&daily=sunrise,sunset&timezone=auto&forecast_days=1`
                        ]
                        weatherProc.running = true
                    }
                } catch (e) {
                    console.warn("[WWeatherCard] geolocation failed:", e)
                }
            }
        }
    }

    Process {
        id: weatherProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    const cur = data.current
                    root.tempF = cur.temperature_2m
                    root.feelsLikeF = cur.apparent_temperature
                    root.humidity = cur.relative_humidity_2m
                    root.windMph = cur.wind_speed_10m
                    root.windDirDeg = cur.wind_direction_10m
                    root.windDir = root.degreesToCompass(cur.wind_direction_10m)
                    root.weatherCode = cur.weather_code
                    root.haveData = true
                    root.sunrise = data.daily?.sunrise?.[0] ?? ""
                    root.sunset = data.daily?.sunset?.[0] ?? ""
                } catch (e) {
                    console.warn("[WWeatherCard] forecast parse failed:", e)
                }
            }
        }
    }

    function refresh() { geoProc.running = true }

    Component.onCompleted: refresh()
    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 18

        ColumnLayout {
            spacing: 6

            RowLayout {
                spacing: 6
                Text { text: "thermostat"; font.family: "Material Symbols Rounded"; font.pixelSize: 16; color: WallustTheme.accent }
                Text {
                    text: root.haveData ? Math.round(root.tempF) + "°F" : "--°F"
                    color: WallustTheme.textPrimary
                    font.pixelSize: 14
                    font.bold: true
                }
                // "Feels like" only when it actually differs from the raw
                // reading by a whole degree - showing "feels 84°" right
                // next to "84°F" says nothing the bare temperature didn't.
                Text {
                    visible: root.haveData && Math.round(root.feelsLikeF) !== Math.round(root.tempF)
                    text: "feels " + Math.round(root.feelsLikeF) + "°"
                    color: WallustTheme.textSecondary
                    font.pixelSize: 11
                }
            }
            RowLayout {
                spacing: 6
                Text { text: "air"; font.family: "Material Symbols Rounded"; font.pixelSize: 16; color: WallustTheme.textSecondary }
                Text {
                    text: root.haveData ? Math.round(root.windMph) + " mph" : "-- mph"
                    color: WallustTheme.textPrimary
                    font.pixelSize: 13
                }
            }
            RowLayout {
                spacing: 6
                visible: root.sunrise !== ""
                Text { text: "wb_twilight"; font.family: "Material Symbols Rounded"; font.pixelSize: 16; color: WallustTheme.textSecondary }
                Text {
                    text: root.sunrise !== "" ? Qt.formatTime(new Date(root.sunrise), WidgetsState.twelveHour ? "h:mm AP" : "HH:mm") : ""
                    color: WallustTheme.textPrimary
                    font.pixelSize: 13
                }
                Text { text: "bedtime"; font.family: "Material Symbols Rounded"; font.pixelSize: 16; color: WallustTheme.textSecondary }
                Text {
                    text: root.sunset !== "" ? Qt.formatTime(new Date(root.sunset), WidgetsState.twelveHour ? "h:mm AP" : "HH:mm") : ""
                    color: WallustTheme.textPrimary
                    font.pixelSize: 13
                }
            }
            RowLayout {
                spacing: 6
                Text { text: "humidity_percentage"; font.family: "Material Symbols Rounded"; font.pixelSize: 16; color: WallustTheme.textSecondary }
                Text {
                    text: root.haveData ? Math.round(root.humidity) + "%" : "--%"
                    color: WallustTheme.textPrimary
                    font.pixelSize: 13
                }
            }
            RowLayout {
                spacing: 6

                // Real compass needle, not just a static glyph - rotates
                // to the actual wind_direction_10m degree value (0=N,
                // rotation is clockwise same as compass bearings), not
                // just the 8-point letter next to it.
                Item {
                    id: compass
                    implicitWidth: 20
                    implicitHeight: 20

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        antialiasing: true
                        color: "transparent"
                        border.width: 1
                        border.color: WallustTheme.textSecondary
                    }

                    Rectangle {
                        width: 2
                        height: compass.height / 2 - 1
                        radius: 1
                        antialiasing: true
                        color: WallustTheme.accent
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.verticalCenter
                        transformOrigin: Item.Bottom
                        rotation: root.windDirDeg
                        Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    text: root.haveData ? root.windDir : "-"
                    color: WallustTheme.textPrimary
                    font.pixelSize: 13
                }
            }
        }

        // Flexible spacer, not Layout.alignment - alignment alone doesn't
        // push a RowLayout child to the far edge; it only positions it
        // within space that's already been allotted to it, and nothing
        // else in this row claims the leftover width now that row spans
        // the card's real ~284px. This is what actually reaches the edge.
        Item { Layout.fillWidth: true }

        // Condition glyph only - no avatar sticker badge underneath it.
        // Still driven by the real weather_code (sun/cloud/rain/snow/storm),
        // just bigger and brighter for more presence on its own.
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 56
            implicitHeight: 56

            Rectangle {
                anchors.centerIn: parent
                width: 56
                height: 56
                radius: 28
                antialiasing: true
                color: WallustTheme.accent
                opacity: 0.25
            }
            Text {
                anchors.centerIn: parent
                text: root.weatherGlyph(root.weatherCode)
                font.family: "Material Symbols Rounded"
                font.pixelSize: 34
                color: WallustTheme.accent
            }
        }
    }
}
