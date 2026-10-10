import QtQuick
import QtQuick.Layouts
import qs.services

Item {
    id: root
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    // Click the clock to flip between 24-hour and 12-hour. The format is
    // shared with the weather card's sun times through WidgetsState.
    property string timeString: formatNow(new Date())
    // Day name only lived on the calendar card below this one - reading it
    // meant looking at a different card entirely just to confirm what day
    // it is, even though the clock is the thing glanced at most.
    property string dayString: formatDay(new Date())

    // Digits are always two-wide per field (12h hours are zero-padded too),
    // so the big time keeps one fixed width. AM/PM goes on the day line.
    function formatNow(d) {
        const h24 = d.getHours()
        const h = WidgetsState.twelveHour ? (h24 % 12 || 12) : h24
        const pad = n => (n < 10 ? "0" : "") + n
        return pad(h) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds())
    }
    function formatDay(d) {
        const day = Qt.formatDate(d, "dddd")
        return WidgetsState.twelveHour ? day + "  " + (d.getHours() < 12 ? "AM" : "PM") : day
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date()
            root.timeString = root.formatNow(now)
            root.dayString = root.formatDay(now)
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            WidgetsState.twelveHour = !WidgetsState.twelveHour
            const now = new Date()
            root.timeString = root.formatNow(now)
            root.dayString = root.formatDay(now)
        }
    }

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 2

        Text {
            id: clockText
            Layout.alignment: Qt.AlignHCenter
            text: root.timeString
            color: WallustTheme.textPrimary
            // No specific vintage serif is confirmed installed on this
            // system, so this is the honest available approximation of a
            // "heavy retro block" look rather than a guessed-at font name
            // that might silently fall back to something generic.
            font.family: "monospace"
            font.pixelSize: 46
            font.bold: true
            font.letterSpacing: 2
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.dayString.toUpperCase()
            color: WallustTheme.textSecondary
            font.family: "monospace"
            font.pixelSize: 13
            font.letterSpacing: 3
        }
    }
}
