import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

Item {
    id: classicFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false

    readonly property string fullTimeStr: {
        if (widget && widget.timeStr !== undefined && widget.timeStr !== null && String(widget.timeStr) !== "") {
            return String(widget.timeStr);
        }
        if (typeof DateTime !== "undefined" && DateTime.time !== undefined && DateTime.time !== null && String(DateTime.time) !== "") {
            return String(DateTime.time);
        }
        var h = widget && widget.hourStr !== undefined ? String(widget.hourStr) : (typeof DateTime !== "undefined" && DateTime.hour !== undefined ? String(DateTime.hour) : "14");
        var m = widget && widget.minuteStr !== undefined && String(widget.minuteStr) !== "" ? String(widget.minuteStr) : "";
        var s = widget && widget.secondStr !== undefined && String(widget.secondStr) !== "" ? String(widget.secondStr) : "";
        if (s !== "") return h + ":" + m + ":" + s;
        if (m !== "") return h + ":" + m;
        return h;
    }

    readonly property var parsedTime: {
        var str = fullTimeStr.trim();
        var ap = "";

        var ampmMatch = str.match(/\s*([a-zA-Z.]+)\s*$/);
        if (ampmMatch && /^(am|pm|a\.m\.|p\.m\.)$/i.test(ampmMatch[1])) {
            ap = ampmMatch[1].toUpperCase().replace(/\./g, "");
            str = str.substring(0, ampmMatch.index).trim();
        }

        var parts = str.split(":");
        var h = parts.length > 0 && parts[0] !== "" ? parts[0] : (widget && widget.hourStr ? String(widget.hourStr) : "14");
        var m = parts.length > 1 ? parts[1] : "";
        var s = parts.length > 2 ? parts[2] : "";

        return {
            hours: h,
            minutes: m,
            seconds: s,
            ampm: ap,
            hasMinutes: m !== "",
            hasSeconds: s !== ""
        };
    }

    implicitWidth: bodyLoader.item ? bodyLoader.item.implicitWidth : 0
    implicitHeight: bodyLoader.item ? bodyLoader.item.implicitHeight : 0

    Loader {
        id: bodyLoader
        anchors.centerIn: parent
        sourceComponent: classicFaceRoot.isVertical ? sideBodyComponent : topBodyComponent
    }

    Component {
        id: topBodyComponent

        Item {
            id: plate
            readonly property real fullH: (widget && widget.barWindow) ? widget.barWindow.barHeight : 32
            readonly property bool wide: widget ? widget.hovered : false
            implicitWidth: Math.max(widthProbe.implicitWidth + 48, dateText.implicitWidth + 8)
            implicitHeight: fullH

            // the time plus room for the seconds, so the plate never changes size
            Text {
                id: widthProbe
                visible: false
                renderType: Text.NativeRendering
                text: "00:00"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 20
                font.weight: Font.Bold
            }

            // soft highlight along the top edge: the plate reads as raised
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: -4; rightMargin: -4 }
                height: 1
                color: Qt.rgba(1, 1, 1, 0.09)
            }

            // Everything is placed by hand inside a plate of fixed size: hovering only fades the seconds in, nothing reflows.
            Text {
                renderType: Text.NativeRendering
                id: timeText
                x: Math.round((plate.width - implicitWidth) / 2)
                y: 1
                textFormat: Text.StyledText
                readonly property string colon: "<font color='" + ThemeBackend.blue.toString() + "'>:</font>"
                text: classicFaceRoot.parsedTime.hours + colon + classicFaceRoot.parsedTime.minutes
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 20
                lineHeightMode: Text.FixedHeight
                lineHeight: 17
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: ThemeBackend.text
            }

            // seconds: an overlay to the right of the minutes
            Text {
                renderType: Text.NativeRendering
                x: timeText.x + timeText.implicitWidth + 1
                y: 5
                text: ":" + classicFaceRoot.parsedTime.seconds
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: ThemeBackend.subtext0
                opacity: (plate.wide && classicFaceRoot.parsedTime.hasSeconds) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            Text {
                renderType: Text.NativeRendering
                id: dateText
                visible: widget ? widget.showDate : true
                x: Math.round((plate.width - implicitWidth) / 2)
                y: 22
                text: DateTime.format("ddd, d MMM", DateTime.now).toUpperCase()
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 9
                font.letterSpacing: 1
                lineHeightMode: Text.FixedHeight
                lineHeight: 8
                font.weight: Font.Medium
                color: ThemeBackend.subtext0
            }

            // progress across the minute, on the very bottom edge of the plate (the face sits 16 px inside it)
            Rectangle {
                id: track
                x: -6
                width: parent.width + 12
                y: parent.height - 2
                height: 2
                radius: 1
                color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.08)
                Rectangle {
                    height: parent.height
                    radius: 1
                    width: parent.width * Math.min(1, (parseInt(classicFaceRoot.parsedTime.seconds) || parseInt(DateTime.second) || 0) / 60)
                    color: ThemeBackend.blue
                    Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
                }
            }
        }
    }

    Component {
        id: sideBodyComponent

        Column {
            id: sideTimeCol
            spacing: widget ? widget.s(1) : 1

            Text {
                renderType: Text.NativeRendering
                anchors.horizontalCenter: parent.horizontalCenter
                text: parsedTime.hours
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 13 : 14) : 14
                font.weight: Font.Black
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.blue, 1.1) : ThemeBackend.blue
            }

            Text {
                renderType: Text.NativeRendering
                visible: parsedTime.hasMinutes
                anchors.horizontalCenter: parent.horizontalCenter
                text: parsedTime.minutes
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 13 : 14) : 14
                font.weight: Font.Black
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.blue, 1.1) : ThemeBackend.blue
            }

            Text {
                renderType: Text.NativeRendering
                visible: parsedTime.hasSeconds
                anchors.horizontalCenter: parent.horizontalCenter
                text: parsedTime.seconds
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 11 : 12) : 12
                font.weight: Font.Bold
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.blue, 1.1) : ThemeBackend.blue
            }

            Text {
                renderType: Text.NativeRendering
                visible: parsedTime.ampm !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: parsedTime.ampm
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 8 : 9) : 9
                font.weight: Font.Bold
                color: ThemeBackend.subtext0
            }

            Item {
                visible: widget ? widget.showDate : true
                width: widget ? widget.s(widget.isCompact ? 14 : 16) : 16
                height: widget ? widget.s(10) : 10
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 2
                    radius: 1
                    color: ThemeBackend.surface1
                }
            }

            Text {
                renderType: Text.NativeRendering
                visible: widget ? widget.showDate : true
                anchors.horizontalCenter: parent.horizontalCenter
                text: widget ? widget.dayStr : (typeof DateTime !== "undefined" ? DateTime.day : "18")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 11 : 12) : 12
                font.weight: Font.Bold
                color: ThemeBackend.text
            }

            Text {
                renderType: Text.NativeRendering
                visible: widget ? widget.showDate : true
                anchors.horizontalCenter: parent.horizontalCenter
                text: widget ? widget.monthStr : (typeof DateTime !== "undefined" ? DateTime.monthShort : "Sep")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 9 : 10) : 10
                font.weight: Font.Bold
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.subtext0, 1.08) : ThemeBackend.subtext0
            }
        }
    }
}
