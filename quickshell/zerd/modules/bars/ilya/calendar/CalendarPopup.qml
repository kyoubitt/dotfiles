import QtQuick
import QtQuick.Layouts
import "../"

// Calendar, clock and weather in one opaque card: three columns of the same weight, 24 px apart.
// Calendar on the left (arrows change the month, a day can be picked, "Today" comes back), the clock with the
// hourly forecast in the middle, the weather of the chosen day on the right (arrows page through the days).
// Left and Right keys and the scroll wheel do the same.
Item {
    id: root
    visible: false
    focus: true

    readonly property int pad: 20
    readonly property int gap: 24

    property real intro: 0
    property var exitCallback: null

    function s(v) { return Scaler.s(v); }

    function startExit(onFinished) {
        exitCallback = onFinished;
        introAnim.stop();
        outAnim.restart();
    }
    function resetAndPlayIntro() {
        outAnim.stop();
        intro = 0;
        introAnim.restart();
    }
    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            Weather.refresh(false);
            resetAndPlayIntro();
        } else {
            introAnim.stop();
            outAnim.stop();
            intro = 0;
        }
    }
    NumberAnimation { id: introAnim; target: root; property: "intro"; to: 1; duration: 260; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: outAnim
        NumberAnimation { target: root; property: "intro"; to: 0; duration: 170; easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                if (root.exitCallback) {
                    const cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                }
            }
        }
    }

    // ---- calendar state
    property int monthOffset: 0
    property string selectedKey: ""
    readonly property date today: DateTime.now
    readonly property string todayKey: Qt.formatDate(today, "yyyy-M-d")
    readonly property date viewMonth: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    readonly property var cells: {
        const first = viewMonth;
        const lead = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - lead + i);
            const key = Qt.formatDate(d, "yyyy-M-d");
            out.push({ day: d.getDate(), inMonth: d.getMonth() === first.getMonth(), key: key, today: key === root.todayKey });
        }
        return out;
    }

    // ---- weather state
    property int dayIndex: 0
    readonly property var days: Weather.data.forecast ?? []
    readonly property var day: days[Math.min(dayIndex, Math.max(0, days.length - 1))] ?? null
    function stepDay(d) { dayIndex = Math.max(0, Math.min(Math.max(0, days.length - 1), dayIndex + d)); }
    function stepMonth(d) { monthOffset += d; }
    function sym(glyph) { return ThemeBackend.symOf(glyph); }

    Shortcut {
        sequence: "Left"
        enabled: root.visible
        onActivated: calArea.hovered ? root.stepMonth(-1) : root.stepDay(-1)
    }
    Shortcut {
        sequence: "Right"
        enabled: root.visible
        onActivated: calArea.hovered ? root.stepMonth(1) : root.stepDay(1)
    }

    component Arrow: Rectangle {
        id: arrow
        property string glyph: "chevron_left"
        signal tapped()
        width: 32; height: 32; radius: 16
        color: am.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
        Behavior on color { ColorAnimation { duration: 110 } }
        Text {
            renderType: Text.NativeRendering
            anchors.centerIn: parent
            text: arrow.glyph
            font.family: ThemeBackend.symbolFont
            font.pixelSize: 18
            color: ThemeBackend.text
        }
        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: arrow.tapped() }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.base           // opaque: nothing behind the popup shows through
        opacity: root.intro
        scale: 0.96 + 0.04 * root.intro
        transformOrigin: Item.Top
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.pad
            spacing: root.gap

            // ===== calendar
            Rectangle {
                id: calCol
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                radius: ThemeBackend.borderRadius - 4
                color: ThemeBackend.surface0

                HoverHandler { id: calArea }
                WheelHandler { onWheel: event => root.stepMonth(event.angleDelta.y > 0 ? -1 : 1) }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Arrow { glyph: "chevron_left"; onTapped: root.stepMonth(-1) }
                        Text {
                            renderType: Text.NativeRendering
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.locale().standaloneMonthName(root.viewMonth.getMonth(), Locale.LongFormat) + " " + root.viewMonth.getFullYear()
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            visible: root.monthOffset !== 0
                            width: todayLabel.implicitWidth + 20; height: 32; radius: 16
                            color: ThemeBackend.blue
                            Text {
                                id: todayLabel
                                renderType: Text.NativeRendering
                                anchors.centerIn: parent
                                text: "Today"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: ThemeBackend.crust
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.monthOffset = 0; root.selectedKey = root.todayKey } }
                        }
                        Arrow { glyph: "chevron_right"; onTapped: root.stepMonth(1) }
                    }

                    Grid {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        readonly property real cw: width / 7
                        readonly property real ch: (height) / 7
                        Repeater {
                            model: 7
                            delegate: Item {
                                required property int index
                                width: parent.cw; height: parent.ch
                                Text {
                                    renderType: Text.NativeRendering
                                    anchors.centerIn: parent
                                    text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat).slice(0, 2).toUpperCase()
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.5
                                    color: ThemeBackend.subtext0
                                }
                            }
                        }
                        Repeater {
                            model: root.cells
                            delegate: Item {
                                id: cell
                                required property var modelData
                                width: parent.cw; height: parent.ch
                                readonly property bool picked: root.selectedKey === modelData.key
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height) - 4
                                    height: width
                                    radius: width / 2
                                    color: cell.modelData.today ? ThemeBackend.blue : (cell.picked ? Qt.alpha(ThemeBackend.blue, 0.28) : (cm.containsMouse ? ThemeBackend.surface1 : "transparent"))
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    renderType: Text.NativeRendering
                                    anchors.centerIn: parent
                                    text: cell.modelData.day
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 13
                                    font.weight: cell.modelData.today ? Font.Bold : Font.Medium
                                    color: cell.modelData.today ? ThemeBackend.crust : (cell.modelData.inMonth ? ThemeBackend.text : ThemeBackend.overlay0)
                                }
                                MouseArea {
                                    id: cm
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedKey = cell.modelData.key
                                }
                            }
                        }
                    }
                }
            }

            // ===== clock and the hours of the chosen day
            Item {
                id: midCol
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true

                WheelHandler { onWheel: event => root.stepDay(event.angleDelta.y > 0 ? -1 : 1) }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    Item { Layout.fillHeight: true }
                    Text {
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignHCenter
                        text: DateTime.hour + ":" + DateTime.minute
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 56
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                        color: ThemeBackend.text
                    }
                    Text {
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignHCenter
                        text: DateTime.format("dddd, d MMMM", DateTime.now)
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 16
                        color: ThemeBackend.subtext0
                    }
                    Item { Layout.preferredHeight: 18 }

                    // equal bubbles in one row
                    Row {
                        id: hours
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        readonly property var items: root.day ? (root.day.hourly ?? []).slice(0, 8) : []
                        readonly property real bw: Math.max(36, Math.min(48, (midCol.width - 7 * spacing) / 8))
                        Repeater {
                            model: hours.items
                            delegate: Rectangle {
                                required property var modelData
                                width: hours.bw; height: 84; radius: width / 2
                                color: ThemeBackend.surface0
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        renderType: Text.NativeRendering
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.time.slice(0, 2)
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 11
                                        font.features: { "tnum": 1 }
                                        color: ThemeBackend.subtext0
                                    }
                                    Text {
                                        renderType: Text.NativeRendering
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.sym(modelData.icon) || modelData.icon
                                        font.family: root.sym(modelData.icon) !== "" ? ThemeBackend.symbolFont : ThemeBackend.iconFont
                                        font.pixelSize: 20
                                        color: modelData.hex
                                    }
                                    Text {
                                        renderType: Text.NativeRendering
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.temp + "°"
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        font.features: { "tnum": 1 }
                                        color: ThemeBackend.text
                                    }
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            // ===== weather
            Rectangle {
                id: weatherCol
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                radius: ThemeBackend.borderRadius - 4
                color: ThemeBackend.surface0

                WheelHandler { onWheel: event => root.stepDay(event.angleDelta.y > 0 ? -1 : 1) }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Arrow { glyph: "chevron_left"; onTapped: root.stepDay(-1) }
                        Text {
                            renderType: Text.NativeRendering
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.day ? (root.dayIndex === 0 ? "Today" : (root.dayIndex === 1 ? "Tomorrow" : root.day.day_full)) : "Weather"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                        }
                        Arrow { glyph: "chevron_right"; onTapped: root.stepDay(1) }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            renderType: Text.NativeRendering
                            text: root.day ? (root.sym(root.day.icon) || root.day.icon) : ""
                            font.family: root.day && root.sym(root.day.icon) !== "" ? ThemeBackend.symbolFont : ThemeBackend.iconFont
                            font.pixelSize: 56
                            color: root.day ? root.day.hex : ThemeBackend.text
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                text: root.day ? (root.dayIndex === 0 && Weather.data.current_temp !== "" ? Weather.data.current_temp : root.day.max) + Weather.unitSym : "--"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 44
                                fontSizeMode: Text.Fit
                                minimumPixelSize: 24
                                font.weight: Font.Bold
                                font.features: { "tnum": 1 }
                                color: ThemeBackend.text
                            }
                            Text {
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: root.day ? root.day.desc + "   " + root.day.min + "° / " + root.day.max + "°" : ""
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 13
                                color: ThemeBackend.subtext0
                            }
                        }
                    }

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: Location.city
                        elide: Text.ElideRight
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 13
                        color: ThemeBackend.subtext0
                    }

                    Item { Layout.fillHeight: true }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        columnSpacing: 8
                        Repeater {
                            model: root.day ? [
                                { s: "air", v: root.day.wind + (Weather.unit === "imperial" ? " mph" : " km/h") },
                                { s: "humidity_percent", v: root.day.humidity + "%" },
                                { s: "rainy", v: root.day.pop + "%" },
                                { s: "thermostat", v: root.day.feels_like + "°" }
                            ] : []
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 62
                                radius: 12
                                color: ThemeBackend.surface1
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        renderType: Text.NativeRendering
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.s
                                        font.family: ThemeBackend.symbolFont
                                        font.pixelSize: 18
                                        color: ThemeBackend.subtext0
                                    }
                                    Text {
                                        renderType: Text.NativeRendering
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.v
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: ThemeBackend.text
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // TEMP DEBUG
    Component.onCompleted: console.log("CALDBG ready, days", days.length, "cells", cells.length)
}
