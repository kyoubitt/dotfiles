import QtQuick
import QtQuick.Layouts
import "../"

// Calendar, clock and weather in one opaque card.
// Left: the month (arrows change the month, a day can be picked, "Today" comes back).
// Middle: the clock inside a full circle of 24 hour bubbles for the chosen day; the wheel, the arrows and a drag
//         along the ring move through days, past days included.
// Right: the weather of the chosen day. Days without data are shown dim with "No data".
// Left and Right keys do the same as the arrows.
Item {
    id: root
    visible: false
    focus: true

    readonly property int pad: 20
    readonly property int gap: 24

    property real intro: 0
    property var exitCallback: null

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
            dayOffset = 0;
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

    // ---- the chosen day: an offset from today, negative for past days
    readonly property real dayMs: 86400000
    readonly property date now: DateTime.now
    readonly property date todayStart: new Date(now.getFullYear(), now.getMonth(), now.getDate())
    property int dayOffset: 0
    readonly property date selDate: new Date(todayStart.getFullYear(), todayStart.getMonth(), todayStart.getDate() + dayOffset)
    readonly property string selKey: Qt.formatDate(selDate, "yyyy-M-d")
    readonly property string selIso: Qt.formatDate(selDate, "yyyy-MM-dd")
    function stepDay(d) { dayOffset = Math.max(-90, Math.min(90, dayOffset + d)); }
    function pickDate(date) {
        const start = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        dayOffset = Math.round((start.getTime() - todayStart.getTime()) / dayMs);
    }

    // ---- calendar month: follows the chosen day, and can also be browsed on its own
    property int monthOffset: 0
    onSelDateChanged: monthOffset = (selDate.getFullYear() - todayStart.getFullYear()) * 12 + selDate.getMonth() - todayStart.getMonth()
    function stepMonth(d) { monthOffset += d; }
    readonly property date viewMonth: new Date(todayStart.getFullYear(), todayStart.getMonth() + monthOffset, 1)
    readonly property var cells: {
        const first = viewMonth;
        const lead = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - lead + i);
            const key = Qt.formatDate(d, "yyyy-M-d");
            out.push({ date: d, day: d.getDate(), inMonth: d.getMonth() === first.getMonth(), key: key, today: key === Qt.formatDate(todayStart, "yyyy-M-d") });
        }
        return out;
    }

    // ---- weather of the chosen day (null when there is none)
    readonly property var days: Weather.data.forecast ?? []
    readonly property var day: {
        for (const d of days) if (d.date === selIso) return d;
        return null;
    }
    // the value for one hour of the day: the three-hour step that covers it
    function stepFor(hour) {
        if (!day) return null;
        const base = Math.floor(hour / 3) * 3;
        for (const h of day.hourly) if (h.hour === base) return h;
        return null;
    }
    function sym(glyph) { return ThemeBackend.symOf(glyph); }
    readonly property string dayCaption: dayOffset === 0 ? "Today" : (dayOffset === 1 ? "Tomorrow" : (dayOffset === -1 ? "Yesterday" : (dayOffset > 0 ? "In " + dayOffset + " days" : -dayOffset + " days ago")))

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
        implicitWidth: 32; implicitHeight: 32; radius: 16
        color: am.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1
        Behavior on color { ColorAnimation { duration: 110 } }
        Text {
            renderType: Text.NativeRendering
            anchors.centerIn: parent
            text: arrow.glyph
            font.family: ThemeBackend.symbolFont
            font.variableAxes: ({ "wght": 600, "opsz": 20 })
            font.pixelSize: 18
            color: ThemeBackend.text
        }
        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Sounds.playSfx("reusables/iconbutton/click.wav", 0.6); arrow.tapped() } }
    }

    component Pill: Rectangle {
        id: pill
        property string label: ""
        signal tapped()
        implicitWidth: pillText.implicitWidth + 24; implicitHeight: 32; radius: 16
        color: ThemeBackend.blue
        Text {
            id: pillText
            renderType: Text.NativeRendering
            anchors.centerIn: parent
            text: pill.label
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: ThemeBackend.crust
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav", 0.6); pill.tapped() } }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.base           // solid: nothing behind the popup shows through
        opacity: root.intro
        scale: 0.96 + 0.04 * root.intro
        transformOrigin: Item.Top
        clip: true

        GlassSheen {}

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
                        Arrow { glyph: "chevron_right"; onTapped: root.stepMonth(1) }
                    }

                    // a plain item with hand-placed cells: no positioner, so no size loop with the layout
                    Item {
                        id: grid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        readonly property real cw: width / 7
                        readonly property real ch: height / 7
                        Repeater {
                            model: 7
                            delegate: Item {
                                required property int index
                                x: index * grid.cw; y: 0
                                width: grid.cw; height: grid.ch
                                Text {
                                    renderType: Text.NativeRendering
                                    anchors.centerIn: parent
                                    text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat).slice(0, 2).toUpperCase()
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: ThemeBackend.subtext0
                                }
                            }
                        }
                        Repeater {
                            model: root.cells
                            delegate: Item {
                                id: cell
                                required property var modelData
                                required property int index
                                x: (index % 7) * grid.cw; y: (Math.floor(index / 7) + 1) * grid.ch
                                width: grid.cw; height: grid.ch
                                readonly property bool picked: root.selKey === modelData.key
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height) - 4
                                    height: width
                                    radius: width / 2
                                    color: cell.picked ? ThemeBackend.blue : (cm.containsMouse ? ThemeBackend.surface2 : "transparent")
                                    border.width: (cell.modelData.today && !cell.picked) ? 2 : 0
                                    border.color: ThemeBackend.blue
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    renderType: Text.NativeRendering
                                    anchors.centerIn: parent
                                    text: cell.modelData.day
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 14
                                    font.weight: (cell.picked || cell.modelData.today) ? Font.Bold : Font.Medium
                                    font.features: { "tnum": 1 }
                                    color: cell.picked ? ThemeBackend.crust : (cell.modelData.inMonth ? ThemeBackend.text : ThemeBackend.overlay1)
                                }
                                MouseArea {
                                    id: cm
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { Sounds.playSfx("reusables/clickbutton/click2.wav", 0.5); root.pickDate(cell.modelData.date) }
                                }
                            }
                        }
                    }
                }
            }

            // ===== the clock inside the ring of hours
            Item {
                id: midCol
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true

                Item {
                    id: ring
                    readonly property real bubble: 38
                    readonly property real big: 48
                    width: Math.min(midCol.width, midCol.height)
                    height: width
                    anchors.centerIn: parent
                    readonly property real radius: (width - big) / 2

                    WheelHandler { onWheel: event => root.stepDay(event.angleDelta.y > 0 ? -1 : 1) }
                    DragHandler {
                        id: drag
                        target: null
                        property real last: 0
                        onActiveChanged: last = 0
                        onTranslationChanged: {
                            const d = translation.x - last;
                            if (Math.abs(d) >= 44) { root.stepDay(d < 0 ? 1 : -1); last = translation.x; }
                        }
                    }

                    // 24 bubbles on a full circle, 0 h at the top
                    Repeater {
                        model: 24
                        delegate: Item {
                            id: hb
                            required property int index
                            readonly property var st: root.stepFor(index)
                            readonly property bool current: root.dayOffset === 0 && DateTime.now.getHours() === index
                            readonly property real size: current ? ring.big : ring.bubble
                            readonly property real ang: (index / 24) * 2 * Math.PI - Math.PI / 2
                            x: ring.width / 2 + ring.radius * Math.cos(ang) - size / 2
                            y: ring.height / 2 + ring.radius * Math.sin(ang) - size / 2
                            width: size; height: size
                            opacity: root.day ? 1 : 0.4
                            Behavior on size { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: hb.current ? ThemeBackend.blue : ThemeBackend.surface1
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 0
                                Text {
                                    renderType: Text.NativeRendering
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: hb.st !== null
                                    text: hb.st ? (root.sym(hb.st.icon) || hb.st.icon) : ""
                                    font.family: hb.st && root.sym(hb.st.icon) !== "" ? ThemeBackend.symbolFont : ThemeBackend.iconFont
                                    font.variableAxes: ({ "wght": 600, "opsz": 20 })
                                    font.pixelSize: 16
                                    color: hb.current ? ThemeBackend.crust : (hb.st ? hb.st.hex : ThemeBackend.text)
                                }
                                Text {
                                    renderType: Text.NativeRendering
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: hb.st ? hb.st.temp + "°" : String(hb.index)
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: hb.st ? 12 : 13
                                    font.weight: Font.DemiBold
                                    font.features: { "tnum": 1 }
                                    color: hb.current ? ThemeBackend.crust : (hb.st ? ThemeBackend.text : ThemeBackend.subtext0)
                                }
                            }
                        }
                    }

                    // inside the ring
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: ring.width - 2 * (ring.big + 16)
                        spacing: 4
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
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: Qt.formatDate(root.selDate, "dddd, d MMMM")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 16
                            color: ThemeBackend.text
                        }
                        Text {
                            renderType: Text.NativeRendering
                            Layout.alignment: Qt.AlignHCenter
                            text: root.dayCaption + (root.day ? "" : "  -  no data")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 13
                            color: ThemeBackend.subtext0
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            spacing: 10
                            Arrow { glyph: "chevron_left"; onTapped: root.stepDay(-1) }
                            Pill { label: "Today"; opacity: root.dayOffset === 0 ? 0.35 : 1; onTapped: root.dayOffset = 0 }
                            Arrow { glyph: "chevron_right"; onTapped: root.stepDay(1) }
                        }
                    }
                }
            }

            // ===== weather of the chosen day
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
                            text: root.dayCaption
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                        }
                        Arrow { glyph: "chevron_right"; onTapped: root.stepDay(1) }
                    }

                    Item { Layout.fillHeight: true }

                    // no data for this day
                    Text {
                        renderType: Text.NativeRendering
                        visible: !root.day
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "No weather data for this day"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 14
                        color: ThemeBackend.subtext0
                    }

                    RowLayout {
                        visible: root.day !== null
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            renderType: Text.NativeRendering
                            text: root.day ? (root.sym(root.day.icon) || root.day.icon) : ""
                            font.family: root.day && root.sym(root.day.icon) !== "" ? ThemeBackend.symbolFont : ThemeBackend.iconFont
                            font.variableAxes: ({ "wght": 500, "opsz": 48 })
                            font.pixelSize: 56
                            color: root.day ? root.day.hex : ThemeBackend.text
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                text: root.day ? (root.dayOffset === 0 && Weather.data.current_temp !== "" ? Weather.data.current_temp : root.day.max) + Weather.unitSym : "--"
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
                        visible: root.day !== null
                        Layout.fillWidth: true
                        text: Location.city
                        elide: Text.ElideRight
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 13
                        color: ThemeBackend.subtext0
                    }

                    Item { Layout.fillHeight: true }

                    // wind, humidity, rain, feels like: an icon, a short caption and the value, each in a fixed tile
                    GridLayout {
                        visible: root.day !== null
                        Layout.fillWidth: true
                        columns: 4
                        columnSpacing: 8
                        Repeater {
                            model: root.day ? [
                                { s: "air", c: "Wind", v: root.day.wind + (Weather.unit === "imperial" ? " mph" : " km/h") },
                                { s: "water_drop", c: "Humidity", v: root.day.humidity + "%" },
                                { s: "rainy", c: "Rain", v: root.day.pop + "%" },
                                { s: "thermostat", c: "Feels", v: root.day.feels_like + "°" }
                            ] : []
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 74
                                radius: 12
                                color: ThemeBackend.surface1
                                clip: true
                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 8
                                    spacing: 2
                                    Text {
                                        renderType: Text.NativeRendering
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.s
                                        font.family: ThemeBackend.symbolFont
                                        font.variableAxes: ({ "wght": 600, "opsz": 20 })
                                        font.pixelSize: 18
                                        color: ThemeBackend.subtext0
                                    }
                                    Text {
                                        renderType: Text.NativeRendering
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: modelData.c
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 11
                                        color: ThemeBackend.subtext0
                                    }
                                    Text {
                                        renderType: Text.NativeRendering
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: modelData.v
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 13
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
    onDayOffsetChanged: console.log("CALDBG day", selIso, "offset", dayOffset, "hasData", day !== null)
}
