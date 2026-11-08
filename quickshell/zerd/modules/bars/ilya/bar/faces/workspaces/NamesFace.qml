import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.services as Svc
import "../../../reusables"
import "../../../"

Item {
    id: namesFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false

    property real pillSize: widget ? widget.s(widget.isCompact ? 20 : 24) : 24
    property real pillRadius: widget ? widget.s(widget.isCompact ? 6 : 7) : 7
    property real layoutSpacing: widget ? widget.s(widget.isCompact ? 5 : 6) : 6

    function isShown(index) {
        if (!widget)
            return false;
        if (typeof widget.isShown === "function")
            return widget.isShown(index);
        return true;
    }

    readonly property var shownIndices: {
        if (!widget)
            return [];
        widget.activeIndex;
        widget.workspaceCount;
        widget.hideEmptyWorkspaces;
        widget.niriOccupiedMap;
        widget.swayOccupiedMap;
        widget.mangoOccupiedMap;
        if (Compositor.name === "hyprland")
            Hyprland.workspaces.values;
        let ids = [];
        for (let i = 0; i < widget.workspaceCount; i++) {
            if (isShown(i))
                ids.push(i);
        }
        return ids;
    }

    implicitWidth: wsLayout.implicitWidth
    implicitHeight: wsLayout.implicitHeight

    Rectangle {
        id: activeHighlight
        z: 0
        x: namesFaceRoot.isVertical ? wsLayout.x + (wsLayout.width - width) / 2 : actualStart
        y: namesFaceRoot.isVertical ? actualStart : wsLayout.y + (wsLayout.height - height) / 2
        width: namesFaceRoot.isVertical ? namesFaceRoot.pillSize : actualEnd - actualStart
        height: namesFaceRoot.isVertical ? actualEnd - actualStart : namesFaceRoot.pillSize
        radius: namesFaceRoot.pillRadius
        color: namesGlass.active ? "transparent" : ((widget && widget.isCompact) ? Qt.lighter(ThemeBackend.blue, 1.05) : ThemeBackend.blue)

        GlassFill {
            id: namesGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.blue
            tintAmount: 0.5
            press: 0.3 + 0.7 * activeHighlight.lift
        }

        property int prevIdx: 0
        property int curIdx: widget ? widget.activeIndex : -1

        onCurIdxChanged: {
            if (curIdx >= 0 && prevIdx >= 0) {
                if (curIdx > prevIdx) {
                    endAnim.duration = 200;
                    startAnim.duration = 350;
                } else if (curIdx < prevIdx) {
                    startAnim.duration = 200;
                    endAnim.duration = 350;
                }
            }
            if (curIdx >= 0) {
                prevIdx = curIdx;
            }
        }

        function getPos(index) {
            if (index < 0)
                return 0;
            let pos = 0;
            const shown = namesFaceRoot.shownIndices;
            for (let i = 0; i < shown.length; i++) {
                if (shown[i] === index)
                    break;
                pos += namesFaceRoot.pillSize + namesFaceRoot.layoutSpacing;
            }
            return (namesFaceRoot.isVertical ? wsLayout.y : wsLayout.x) + pos;
        }

        property real targetStart: {
            namesFaceRoot.shownIndices;
            return curIdx >= 0 ? getPos(curIdx) : 0;
        }
        property real targetEnd: (curIdx >= 0) ? (targetStart + namesFaceRoot.pillSize) : 0

        property real actualStart: targetStart
        property real actualEnd: targetEnd

        Behavior on actualStart { NumberAnimation { id: startAnim; duration: 250; easing.type: Easing.OutExpo } }
        Behavior on actualEnd { NumberAnimation { id: endAnim; duration: 250; easing.type: Easing.OutExpo } }

        readonly property bool isMoving: Math.abs(actualStart - targetStart) > 0.5 || Math.abs(actualEnd - targetEnd) > 0.5
        property real lift: (namesGlass.active && isMoving) ? 1.0 : 0.0
        Behavior on lift { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        scale: 1.0 + 0.14 * lift
        transformOrigin: Item.Center

        opacity: (widget && widget.workspaceCount > 0 && widget.activeIndex >= 0) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    AxisFlow {
        id: wsLayout
        vertical: namesFaceRoot.isVertical
        z: 1
        anchors.centerIn: parent
        spacing: namesFaceRoot.layoutSpacing

        Repeater {
            model: widget ? widget.workspaceCount : 0

            delegate: Item {
                id: wsPill
                required property int index

                property bool isOccupied: widget ? widget.isOccupied(index) : false
                property bool isActive: widget ? (index === widget.activeIndex) : false
                property bool isHovered: wsPillMouse.containsMouse
                property bool initAnimTrigger: false
                property bool shown: namesFaceRoot.isShown(index)

                visible: shown
                width: namesFaceRoot.isVertical ? namesFaceRoot.pillSize : (shown ? namesFaceRoot.pillSize : 0)
                height: namesFaceRoot.isVertical ? (shown ? namesFaceRoot.pillSize : 0) : namesFaceRoot.pillSize

                Rectangle {
                    anchors.fill: parent
                    radius: namesFaceRoot.pillRadius
                    color: namesHoverGlass.active ? "transparent" : wsPill.isHovered
                        ? Qt.alpha(ThemeBackend.text, 0.1)
                        : (wsPill.isActive ? "transparent" : (wsPill.isOccupied ? Qt.alpha(ThemeBackend.text, 0.15) : "transparent"))

                    Behavior on color { ColorAnimation { duration: 250 } }

                    scale: wsPill.isHovered && !wsPill.isActive ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                    GlassFill {
                        id: namesHoverGlass
                        anchors.fill: parent
                        radius: parent.radius
                        allowed: wsPill.isHovered && !wsPill.isActive
                        tintColor: ThemeBackend.text
                        tintAmount: 0.15
                        press: wsPillMouse.pressed ? 0.8 : 0.25
                    }
                }

                opacity: initAnimTrigger ? 1.0 : 0.0
                transform: Translate {
                    x: (!namesFaceRoot.isVertical || wsPill.initAnimTrigger) ? 0 : (widget ? widget.s(15) : 15)
                    y: (namesFaceRoot.isVertical || wsPill.initAnimTrigger) ? 0 : (widget ? widget.s(15) : 15)
                    Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                    Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                }

                Component.onCompleted: {
                    if (widget && widget.barWindow && !widget.barWindow.startupCascadeFinished) {
                        animTimer.interval = index * 60;
                        if (widget.moduleActive) animTimer.start();
                    } else {
                        initAnimTrigger = true;
                    }
                }

                Timer {
                    id: animTimer
                    running: false
                    repeat: false
                    onTriggered: wsPill.initAnimTrigger = true
                }

                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                // the first window's app icon; an empty workspace shows its name, or its number
                readonly property var ws: (Svc.NiriService.allWorkspaces ?? []).find(w => w.output === (widget ? widget.myOutput : "") && w.idx === wsPill.index + 1) ?? null
                readonly property var firstWin: ws ? ((Svc.NiriService.windows ?? []).find(w => w.workspace_id === ws.id) ?? null) : null
                readonly property string iconName: firstWin ? (Svc.AppSearch.lookupDesktopEntry(firstWin.app_id ?? "")?.icon || Svc.AppSearch.guessIcon(firstWin.app_id ?? "")) : ""
                readonly property string iconPath: iconName !== "" ? Quickshell.iconPath(iconName, true) : ""

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    sourceSize: Qt.size(32, 32)
                    fillMode: Image.PreserveAspectFit
                    source: wsPill.iconPath !== "" ? (wsPill.iconPath.startsWith("/") ? "file://" + wsPill.iconPath : wsPill.iconPath) : ""
                    visible: status === Image.Ready
                    opacity: wsPill.isActive || wsPill.isHovered ? 1 : 0.85
                }

                Text {
                    renderType: Text.NativeRendering
                    anchors.centerIn: parent
                    visible: wsPill.iconPath === ""
                    text: wsPill.ws && wsPill.ws.name ? String(wsPill.ws.name).slice(0, 2) : (wsPill.index + 1).toString()
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 13
                    font.weight: wsPill.isActive ? Font.Black : (wsPill.isOccupied ? Font.Bold : Font.Medium)
                    color: wsPill.isActive
                        ? (namesGlass.active ? ThemeBackend.text : ThemeBackend.crust)
                        : (wsPill.isOccupied || wsPill.isHovered ? ThemeBackend.text : ThemeBackend.overlay0)
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                MouseArea {
                    id: wsPillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (widget) widget.focusWorkspace(wsPill.index);
                    }
                }
            }
        }
    }
}
