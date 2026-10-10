import QtQuick
import QtQuick.Layouts
import qs.services

Item {
    id: root
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    readonly property date today: new Date()
    readonly property int year: today.getFullYear()
    readonly property int month: today.getMonth() // 0-based
    readonly property int todayDate: today.getDate()

    // Sunday on/before the given date, at local midnight.
    function sundayOnOrBefore(d) {
        const nd = new Date(d)
        nd.setHours(0, 0, 0, 0)
        nd.setDate(nd.getDate() - nd.getDay())
        return nd
    }

    readonly property date monthFirst: new Date(year, month, 1)
    readonly property date firstRowStart: sundayOnOrBefore(monthFirst)

    readonly property var rows: {
        const result = []
        for (let r = 0; r < 6; r++) {
            const rowStart = new Date(firstRowStart)
            rowStart.setDate(rowStart.getDate() + r * 7)
            const days = []
            for (let c = 0; c < 7; c++) {
                const d = new Date(rowStart)
                d.setDate(d.getDate() + c)
                days.push({
                    dayNum: d.getDate(),
                    inMonth: d.getMonth() === month && d.getFullYear() === year,
                    isToday: d.getFullYear() === year && d.getMonth() === month && d.getDate() === todayDate
                })
            }
            result.push(days)
        }
        return result
    }

    readonly property var dayLabels: ["S", "M", "T", "W", "T", "F", "S"]

    ColumnLayout {
        id: col
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: Qt.formatDate(root.today, "MMMM yyyy")
            color: WallustTheme.textPrimary
            font.pixelSize: 18
            font.bold: true
        }

        // Plain Rows throughout (not GridLayout with column-spans - mixing
        // fixed-span header cells with Repeater-generated full-width row
        // items in one GridLayout risks unpredictable auto-placement).
        // Every row uses the identical cell size, so columns line up
        // exactly without relying on a shared layout. Clean 7-column
        // Sun-Sat block - no leading week-number column. Cell size (36x32,
        // 5px spacing) is sized to fill the card's actual available width
        // (~284px) rather than leaving a large blank strip on the right,
        // which is what a tighter 26px cell left behind.
        Row {
            spacing: 5
            Repeater {
                model: root.dayLabels
                delegate: Text {
                    required property string modelData
                    width: 36
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: WallustTheme.textSecondary
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        Repeater {
            model: root.rows
            delegate: Row {
                required property var modelData
                spacing: 5

                Repeater {
                    model: modelData
                    delegate: Item {
                        required property var modelData
                        width: 36
                        height: 32

                        Rectangle {
                            visible: modelData.isToday
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 10
                            antialiasing: true
                            color: WallustTheme.accent
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.dayNum
                            font.pixelSize: 12
                            color: modelData.isToday
                                ? WallustTheme.textOnAccent
                                : (modelData.inMonth ? WallustTheme.textPrimary : WallustTheme.textSecondary)
                            opacity: modelData.inMonth ? 1 : 0.45
                        }
                    }
                }
            }
        }
    }
}
