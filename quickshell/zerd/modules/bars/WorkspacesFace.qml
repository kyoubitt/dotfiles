import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// One slot per workspace on this output. A single accent shape marks the active one and stretches over to the next
// when the workspace changes: the edge it is heading for moves first (the pill motion of ilyamiro's rice, serpantinum,
// AGPL-3.0). Click switches, scrolling over the capsule steps.
BarPill {
    id: root

    property string output: ""
    property string style: Config.options?.bars?.top?.workspaceStyle ?? "pills"
    readonly property var list: (NiriService.allWorkspaces ?? []).filter(ws => ws.output === root.output)
    readonly property int activeIndex: list.findIndex(ws => ws.is_active)
    function iconFor(app: string): string { return AppSearch.lookupDesktopEntry(app)?.icon || AppSearch.guessIcon(app) }

    wheelable: true
    padding: style === "pills" ? 12 : 8

    // Slot geometry along the flow (`len`) and across it (`cross`).
    readonly property int cross: style === "pills" ? 14 : 24
    readonly property int gap: style === "pills" ? 8 : 4
    function appIds(ws: var): var {
        if (!ws || root.style !== "icons") return []
        return (NiriService.windows ?? []).filter(w => w.workspace_id === ws.id).slice(0, 3).map(w => w.app_id ?? "")
    }
    function slotLen(ws: var): real {
        const active = ws?.is_active === true
        if (root.style === "numbers") return 24
        if (root.style === "icons") {
            const n = root.appIds(ws).length
            return n === 0 ? (active ? 28 : 24) : n * 16 + (n - 1) * 3 + 12
        }
        return active ? 32 : 14
    }
    readonly property var lengths: root.list.map(ws => root.slotLen(ws))
    function startOf(i: int): real {
        let s = 0
        for (let j = 0; j < i; j++) s += (root.lengths[j] ?? 0) + root.gap
        return s
    }
    readonly property real total: root.lengths.reduce((a, b) => a + b, 0) + Math.max(0, root.lengths.length - 1) * root.gap

    // scrolling
    property real wheelAcc: 0
    Timer { id: wheelReset; interval: 250; onTriggered: root.wheelAcc = 0 }
    onWheel: event => {
        wheelReset.restart()
        root.wheelAcc += event.angleDelta.y
        while (Math.abs(root.wheelAcc) >= 120) {
            if (root.wheelAcc > 0) { NiriService.focusWorkspaceUp(); root.wheelAcc -= 120 }
            else { NiriService.focusWorkspaceDown(); root.wheelAcc += 120 }
        }
    }

    Item {
        id: track
        implicitWidth: root.vertical ? root.cross : root.total
        implicitHeight: root.vertical ? root.total : root.cross

        // the moving active shape; its two edges run on their own clocks
        property real edgeA: 0
        property real edgeB: 0
        property real lastGoal: 0
        property bool ready: false
        readonly property real goalA: root.activeIndex >= 0 ? root.startOf(root.activeIndex) : 0
        readonly property real goalB: goalA + (root.activeIndex >= 0 ? (root.lengths[root.activeIndex] ?? 0) : 0)
        NumberAnimation { id: animA; target: track; property: "edgeA"; easing.type: Easing.OutQuint }
        NumberAnimation { id: animB; target: track; property: "edgeB"; easing.type: Easing.OutQuint }
        function go(): void {
            if (!track.ready) { track.edgeA = track.goalA; track.edgeB = track.goalB; track.lastGoal = track.goalA; return }
            const forward = track.goalA >= track.lastGoal
            track.lastGoal = track.goalA
            animA.stop(); animB.stop()
            animA.duration = forward ? 400 : 300
            animB.duration = forward ? 300 : 400
            animA.to = track.goalA
            animB.to = track.goalB
            animA.start(); animB.start()
        }
        onGoalAChanged: Qt.callLater(track.go)
        onGoalBChanged: Qt.callLater(track.go)
        Component.onCompleted: { track.go(); track.ready = true }

        Rectangle {
            visible: root.activeIndex >= 0
            x: root.vertical ? 0 : track.edgeA
            y: root.vertical ? track.edgeA : 0
            width: root.vertical ? root.cross : Math.max(0, track.edgeB - track.edgeA)
            height: root.vertical ? Math.max(0, track.edgeB - track.edgeA) : root.cross
            radius: Math.min(width, height) / 2
            antialiasing: true
            color: root.style === "icons" ? BarStyle.accentContainer : BarStyle.accent
        }

        Repeater {
            model: root.list.length
            delegate: Item {
                id: slot
                required property int index
                readonly property var ws: root.list[index]
                readonly property bool active: ws?.is_active === true
                readonly property bool occupied: !!ws?.active_window_id
                readonly property bool urgent: ws?.is_urgent === true
                readonly property var apps: root.appIds(ws)
                readonly property string appKey: apps.join(",")
                x: root.vertical ? 0 : root.startOf(index)
                y: root.vertical ? root.startOf(index) : 0
                width: root.vertical ? root.cross : (root.lengths[index] ?? 0)
                height: root.vertical ? (root.lengths[index] ?? 0) : root.cross
                Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                // pills: the dot of a slot that is not active, a little lighter when windows are open on it
                Rectangle {
                    visible: root.style === "pills" && !slot.active
                    anchors.fill: parent
                    radius: Math.min(width, height) / 2
                    antialiasing: true
                    color: slot.urgent ? BarStyle.danger : Qt.rgba(BarStyle.text.r, BarStyle.text.g, BarStyle.text.b, slot.occupied ? 0.34 : 0.14)
                    scale: ma.pressed ? 0.86 : (hv.hovered ? 1.14 : 1)
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                }
                BarText {
                    visible: root.style === "numbers"
                    anchors.centerIn: parent
                    text: slot.ws?.idx ?? ""
                    color: slot.active ? BarStyle.onAccent : (slot.urgent ? BarStyle.danger : (slot.occupied ? BarStyle.text : BarStyle.subtext))
                    font.weight: slot.active ? Font.Bold : Font.Medium
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Row {
                    visible: root.style === "icons" && slot.apps.length > 0
                    anchors.centerIn: parent
                    spacing: 3
                    opacity: slot.active ? 1 : 0.65
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Repeater {
                        model: slot.appKey.length > 0 ? slot.appKey.split(",") : []
                        delegate: SmartAppIcon { required property string modelData; icon: root.iconFor(modelData); iconSize: 16 }
                    }
                }
                Rectangle {
                    visible: root.style === "icons" && slot.apps.length === 0
                    anchors.centerIn: parent
                    width: 6; height: 6; radius: 3
                    color: slot.active ? BarStyle.onAccentContainer : BarStyle.subtext
                    opacity: slot.active ? 1 : 0.6
                }

                HoverHandler { id: hv; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    anchors.margins: root.style === "pills" ? -3 : 0
                    onClicked: NiriService.switchToWorkspace(slot.ws?.idx ?? 1)
                }
                BarTip { text: "Workspace " + (slot.ws?.idx ?? "") }
            }
        }
    }
}
