import QtQuick

// A keypad calculator. The expression shows small, the answer big; "=" keeps the answer to carry on with.
Column {
    id: root

    property string expr: ""
    readonly property string preview: root.evaluate(expr)
    spacing: 8

    function evaluate(e: string): string {
        const clean = e.replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-")
        if (clean.length === 0 || !/^[0-9+\-*/().%\s]+$/.test(clean) || !/[0-9]/.test(clean)) return ""
        try {
            const v = Function("\"use strict\"; return (" + clean + ")")()
            return (typeof v === "number" && isFinite(v)) ? String(Math.round(v * 1e9) / 1e9) : ""
        } catch (err) { return "" }
    }
    function press(k: string): void {
        if (k === "C") expr = ""
        else if (k === "⌫") expr = expr.slice(0, -1)
        else if (k === "=") { const r = evaluate(expr); if (r.length > 0) expr = r }
        else expr += k
    }

    Rectangle {
        width: parent.width; height: 70; radius: BarStyle.radiusMedium
        color: BarStyle.plateHover
        BarText { x: 14; y: 8; width: parent.width - 28; text: root.expr.length > 0 ? root.expr : " "; horizontalAlignment: Text.AlignRight; color: BarStyle.subtext; elide: Text.ElideLeft }
        BarText { x: 14; y: 30; width: parent.width - 28; text: root.preview.length > 0 ? root.preview : "0"; horizontalAlignment: Text.AlignRight; font.pixelSize: 24; font.weight: Font.DemiBold; elide: Text.ElideLeft; color: root.preview.length > 0 ? BarStyle.text : BarStyle.subtext }
    }
    Grid {
        columns: 4; spacing: 6
        readonly property real cell: (root.width - 18) / 4
        Repeater {
            model: ["C", "(", ")", "÷", "7", "8", "9", "×", "4", "5", "6", "−", "1", "2", "3", "+", "0", ".", "⌫", "="]
            delegate: Rectangle {
                required property string modelData
                readonly property bool op: ["÷", "×", "−", "+", "="].includes(modelData)
                width: parent.cell; height: 38; radius: BarStyle.radiusSmall
                color: modelData === "=" ? BarStyle.accent : (ma.pressed ? BarStyle.border : (op || modelData === "C" ? BarStyle.plateHover : "transparent"))
                border.width: modelData === "=" || op || modelData === "C" ? 0 : 1; border.color: BarStyle.border
                Behavior on color { ColorAnimation { duration: 90 } }
                BarText { anchors.centerIn: parent; text: modelData; font.pixelSize: 15; font.weight: Font.DemiBold; color: modelData === "=" ? BarStyle.onAccent : (op ? BarStyle.accent : BarStyle.text) }
                MouseArea { id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.press(modelData) }
            }
        }
    }
}
