pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.startMenu

Item {
    id: root

    property var screen: null
    property bool horizontal: false
    property bool dockOnLeft: true
    property real floatMarginTop: 0

    // Fade the whole dock in on first load instead of just snapping into
    // existence - the one moment every other hover/press animation in
    // here can't cover on its own.
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    // --- Wifi radio state via rfkill, not Network.qml -----------------
    // Network.qml is nmcli-only, but this machine runs iwd + systemd-networkd
    // with NetworkManager.service disabled, so nmcli errors out silently and
    // Network.wifiEnabled never reflects reality. rfkill works regardless of
    // which network manager is in use.
    property bool wifiEnabled: false

    Process {
        id: wifiStatusProc
        command: ["rfkill", "--json", "list", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    const dev = data.rfkilldevices?.[0]
                    root.wifiEnabled = dev ? (dev.soft === "unblocked" && dev.hard === "unblocked") : false
                } catch (e) {}
            }
        }
    }
    Timer { interval: 4000; running: true; repeat: true; onTriggered: wifiStatusProc.running = true }
    Component.onCompleted: {
        wifiStatusProc.running = true
        root.opacity = 1
    }

    Process { id: wifiToggleProc }
    Timer { id: wifiRecheckTimer; interval: 400; onTriggered: wifiStatusProc.running = true }
    function toggleWifi() {
        root.wifiEnabled = !root.wifiEnabled // optimistic, reconciled by the recheck below
        wifiToggleProc.exec(["rfkill", "toggle", "wifi"])
        wifiRecheckTimer.restart()
    }

    readonly property var brightnessPresets: [0.05, 0.10, 0.15, 0.25, 0.50, 0.75, 1.0]
    readonly property var volumePresets: [0, 0.25, 0.50, 0.75, 1.0]
    function nextPreset(presets, current) {
        return presets.find(p => p > current + 0.02) ?? presets[0]
    }

    function cycleBrightness() {
        const mon = Brightness.getMonitorForScreen(root.screen) ?? Brightness.monitors[0]
        if (!mon) return
        mon.setBrightness(root.nextPreset(root.brightnessPresets, mon.brightness))
    }

    function cycleVolume() {
        if (Audio.sink?.audio.muted) Audio.sink.audio.muted = false
        Audio.setSinkVolume(root.nextPreset(root.volumePresets, Audio.value))
    }

    // Blurred wallpaper strip, cropped from the same absolute screen
    // coordinates the top bar uses (xOff/yOff = where this panel actually
    // sits on screen) - see WTopBarContent's matching comment. Its crop
    // ends exactly at y = floatMarginTop, which is where this one begins,
    // so the blurred result is continuous across the seam.
    Item {
        id: bgLayer
        anchors.fill: parent

        readonly property real screenW: root.screen?.width ?? bgLayer.width
        readonly property real screenH: root.screen?.height ?? bgLayer.height
        readonly property real xOff: root.horizontal ? 0 : (root.dockOnLeft ? 0 : Math.max(0, screenW - bgLayer.width))
        readonly property real yOff: root.horizontal ? 0 : root.floatMarginTop

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: bgLayer.width
                height: bgLayer.height
                // Square corners - the vertical dock runs flush against the
                // top bar and the bottom screen edge, rounded caps there
                // would leave a notch right at the seam.
                radius: root.horizontal ? bgLayer.height / 2 : 0
            }
        }

        Image {
            id: wallpaperCrop
            // visible:false alone used to kill this outright - Qt skips
            // scene-graph rendering for invisible items, so the
            // ShaderEffectSource below (hideSource:true) had nothing to
            // actually capture and the blur was compositing an empty
            // texture; the dock's "backdrop" was just the flat black tint
            // the whole time, letting whatever's behind it read through.
            // layer.enabled here is the fix: it gives this item its own
            // texture that keeps updating regardless of visible, so it can
            // stay hidden (no raw/unblurred frame ever flashes through)
            // while still feeding the blur a live capture.
            visible: false
            layer.enabled: true
            source: Wallpapers.effectiveWallpaperUrl
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            x: -bgLayer.xOff
            y: -bgLayer.yOff
            width: bgLayer.screenW
            height: bgLayer.screenH
            sourceSize.width: width
            sourceSize.height: height
        }

        Item {
            anchors.fill: parent
            visible: Wallpapers.effectiveWallpaperUrl !== "" && wallpaperCrop.status === Image.Ready

            ShaderEffectSource {
                id: blurSource
                sourceItem: wallpaperCrop
                // wallpaperCrop is already shifted by (-xOff, -yOff) above,
                // so its own local (0,0) is where this dock sits on
                // screen - offsetting the crop rect by xOff/yOff *again*
                // here was sampling a doubly-shifted, unrelated strip of
                // the wallpaper (that's what the odd-colored smear was).
                sourceRect: Qt.rect(0, 0, bgLayer.width, bgLayer.height)
                textureSize: Qt.size(bgLayer.width, bgLayer.height)
                hideSource: true
                live: true
                smooth: true
            }

            MultiEffect {
                anchors.fill: parent
                source: blurSource
                saturation: 0.12
                blurEnabled: true
                blurMax: 64
                blur: 1
            }
        }

        Rectangle {
            anchors.fill: parent
            color: ColorUtils.applyAlpha("#000000", 0.45)
        }
    }

    // A bare glyph, dim at rest, that only picks up a faint circle on
    // hover, and a low-alpha accent tint (not a solid fill) when active.
    component DockFlatIcon: Item {
        id: flat
        property string icon: ""
        property bool active: false
        property color iconColor: ColorUtils.applyAlpha(SMColors.fg, 0.8)
        property bool hovered: mouse.containsMouse
        property int baseSize: 24
        property int hoverSize: 30
        // Persistent outline, unlike the hover-only fill above - marks an
        // icon as "its own standalone action" (e.g. power) rather than
        // part of the app/toggle groups around it.
        property color ringColor: "transparent"
        property real ringWidth: 0
        signal clicked()
        signal wheel(int delta)

        scale: mouse.pressed ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        implicitWidth: hoverSize
        implicitHeight: hoverSize

        Rectangle {
            anchors.centerIn: parent
            width: flat.hovered ? flat.hoverSize : flat.baseSize
            height: width
            radius: height / 2
            antialiasing: true
            color: flat.active ? ColorUtils.applyAlpha(SMColors.accent, 0.35)
                : flat.hovered ? ColorUtils.applyAlpha(SMColors.fg, 0.12)
                : "transparent"
            border.width: flat.ringWidth
            border.color: flat.ringColor
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            MaterialSymbol {
                id: flatIcon
                anchors.centerIn: parent
                iconSize: flat.hovered ? 17 : 15
                text: flat.icon
                color: flat.active ? SMColors.accent : flat.iconColor
                Behavior on iconSize { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.75)
                    shadowBlur: 0.6
                    shadowVerticalOffset: 0
                    shadowHorizontalOffset: 0
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: flat.clicked()
            onWheel: wheelEvent => flat.wheel(wheelEvent.angleDelta.y)
        }
    }

    // A circular progress ring with a center icon - for brightness/volume/
    // nightlight specifically, so the pill communicates "these three are a
    // continuous/toggleable level" rather than looking like plain buttons.
    component DockArcGauge: Item {
        id: gauge
        property real value: 0 // 0..1
        property string icon: ""
        property bool active: false
        property color progressColor: SMColors.accent
        // Was a static alpha - this was the one dock control with zero
        // hover feedback at all (DockFlatIcon and DockAppIcon both
        // brighten/grow on hover), so it read as inert next to everything
        // around it. Brightening the track on hover closes that gap
        // without touching the value arc's own color/meaning.
        readonly property color trackColor: gauge.hovered
            ? ColorUtils.applyAlpha(SMColors.fg, 0.4)
            : ColorUtils.applyAlpha(SMColors.fg, 0.25)
        property color iconColor: ColorUtils.applyAlpha(SMColors.fg, 0.85)
        property real arcRadius: 12
        property real lineWidth: 2.4
        property real gapAngle: 40
        property real iconSize: 13
        readonly property bool hovered: mouse.containsMouse
        signal clicked()
        signal rightClicked()
        signal wheel(int delta)

        implicitWidth: 28
        implicitHeight: 28

        scale: mouse.pressed ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        property real displayValue: gauge.active ? 1 : gauge.value
        Behavior on displayValue { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        onDisplayValueChanged: canvas.requestPaint()
        onProgressColorChanged: canvas.requestPaint()
        onTrackColorChanged: canvas.requestPaint()

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const cx = width / 2, cy = height / 2
                const r = gauge.arcRadius
                const lw = gauge.lineWidth
                ctx.lineCap = "round"
                const baseStart = Math.PI / 2 + gauge.gapAngle * Math.PI / 180
                const totalAngle = (360 - 2 * gauge.gapAngle) * Math.PI / 180

                ctx.strokeStyle = gauge.trackColor
                ctx.lineWidth = lw
                ctx.beginPath()
                ctx.arc(cx, cy, r, baseStart, baseStart + totalAngle, false)
                ctx.stroke()

                const progressAngle = Math.max(0, Math.min(1, gauge.displayValue)) * totalAngle
                if (progressAngle > 0.02) {
                    ctx.strokeStyle = gauge.progressColor
                    ctx.lineWidth = lw
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, baseStart, baseStart + progressAngle, false)
                    ctx.stroke()
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: gauge.hovered ? gauge.iconSize + 1.5 : gauge.iconSize
            text: gauge.icon
            color: gauge.active ? gauge.progressColor : gauge.iconColor
            Behavior on iconSize { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.75)
                shadowBlur: 0.6
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouseEvent => mouseEvent.button === Qt.RightButton ? gauge.rightClicked() : gauge.clicked()
            onWheel: wheelEvent => gauge.wheel(wheelEvent.angleDelta.y)
        }
    }

    // A faint capsule just barely darker than the dock's own blurred
    // background - for grouping brightness/volume/nightlight, and
    // do-not-disturb/wifi/bluetooth, into two visual clusters.
    component GhostPill: Item {
        id: pill
        default property alias content: inner.children
        property alias spacing: inner.spacing
        property real padding: 5
        property bool horizontal: false
        property color fillColor: ColorUtils.applyAlpha("#000000", 0.22)
        // A subtle border by default, not just on the pinned-apps pill -
        // the fill alone reads fine over a bright patch of wallpaper, but
        // over a dark one (night sky, a shadowed silhouette) the 22% black
        // fill barely differs from the dock's own already-dark backdrop,
        // so the pill's edge all but disappears and it stops reading as
        // "a grouped control" at all. A thin outline holds up regardless
        // of what's behind it.
        property color borderColor: ColorUtils.applyAlpha(SMColors.fg, 0.18)
        property real borderWidth: 1

        implicitWidth: inner.implicitWidth + padding * 2
        implicitHeight: inner.implicitHeight + padding * 2

        Rectangle {
            anchors.fill: parent
            radius: (pill.horizontal ? height : width) / 2
            antialiasing: true
            color: pill.fillColor
            border.width: pill.borderWidth
            border.color: pill.borderColor
        }

        Grid {
            id: inner
            anchors.centerIn: parent
            spacing: 6
            columns: pill.horizontal ? -1 : 1
            rows: pill.horizontal ? 1 : -1
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
        }
    }

    // A single app icon, shared by the pinned-launcher row and the
    // running-apps row below it. Pinned entries with no open window pass
    // an empty toplevels list - dimmed and click-to-launch instead of
    // click-to-focus.
    component DockAppIcon: Item {
        id: appBtn
        required property string appId
        property var toplevels: []
        // Off inside the pinned pill - the pill already gives that whole
        // group a background, so every icon getting its own on top of it
        // just doubled up into a muddy grey blob.
        property bool showBackplate: true
        // Set by whichever Repeater instantiates this - the pinned row
        // and the running row already know which one they are, no need
        // to look it up reactively here.
        property bool pinned: false
        readonly property bool running: appBtn.toplevels.length > 0
        readonly property bool active: appBtn.toplevels.some(t => t.activated)
        readonly property var desktopEntry: DesktopEntries.byId(appBtn.appId) ?? DesktopEntries.heuristicLookup(appBtn.appId)
        readonly property string displayName: appBtn.desktopEntry?.name ?? appBtn.appId
        readonly property bool hovered: mouse.containsMouse
        // Pin/unpin. Plain click on the small hover badge below - a
        // Ctrl+right-click gesture used to be the only way to do this,
        // but that's an easy combo to botch (a trackpad's right-click
        // gesture doesn't always carry the modifier through cleanly) and
        // it failed completely silently either way.
        signal togglePin()

        implicitWidth: 33
        implicitHeight: 33
        opacity: appBtn.running ? 1 : 0.45
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        scale: mouse.pressed ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        // Always-on backplate, independent of active state - without it,
        // a monochrome or pale icon (folder, the hex launcher glyph)
        // washes out against a light patch of wallpaper. A thin outline
        // ring rather than a filled hazy circle - matches the pinned
        // pill's own outline treatment instead of competing with it, and
        // reads as crisp lines instead of another soft blob stacked on
        // top of the icon underneath.
        Rectangle {
            visible: appBtn.showBackplate
            anchors.centerIn: parent
            width: appIconMask.width + 8
            height: width
            radius: width / 2
            antialiasing: true
            color: "transparent"
            border.width: 1
            border.color: ColorUtils.applyAlpha(SMColors.fg, appBtn.hovered ? 0.4 : 0.2)
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }

        // Soft accent glow behind the icon while it's the active window -
        // a separate layered Rectangle rather than folded into the icon's
        // own effect, since combining mask+colorize+shadow in one
        // MultiEffect was silently breaking the icon's rendering entirely
        // (nothing showed, no errors).
        Rectangle {
            visible: appBtn.active
            anchors.centerIn: parent
            width: appIcon.width * 1.15
            height: width
            radius: width / 2
            color: SMColors.accent

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: SMColors.accent
                shadowBlur: 1.0
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }
        }

        // Every icon cropped to a perfect circle regardless of its own
        // art's shape. Most icon themes bake in transparent padding
        // around the actual glyph (a folder, a hexagon...), so masking
        // the image at its natural size only clips that empty margin
        // into a circle - the visible glyph inside still reads as
        // whatever shape it was drawn as. Rendering the image oversized
        // and centered, then clipping to the mask's bounds, zooms past
        // that padding so the glyph fills the circle edge to edge. Some
        // upstream app icons (Firefox) bake in their own soft drop-shadow
        // right up to the canvas edge instead of transparent padding, so
        // the default zoom that clears everyone else's padding isn't
        // enough to crop that shadow away too - it needs more. Other
        // icons (Vesktop) draw their glyph almost to the edge with barely
        // any margin at all, so the same aggressive zoom chews into real
        // content instead. One crop ratio can't satisfy both, hence the
        // per-app override below rather than chasing a single "correct"
        // global value. No color wash here anymore - it used to tint
        // every icon toward the accent color all the time, not just the
        // active one, which dulled each app's real brand colors for no
        // reason. The active state already reads clearly from the glow
        // above.
        readonly property var iconZoomOverrides: ({ "vesktop": 1.0, "firefox": 1.5 })
        readonly property real iconZoom: appBtn.iconZoomOverrides[appBtn.appId.toLowerCase()] ?? 1.2
        Item {
            id: appIconMask
            anchors.centerIn: parent
            width: appBtn.hovered ? 31 : 27
            height: width
            clip: true
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Image {
                id: appIcon
                anchors.centerIn: parent
                width: parent.width * appBtn.iconZoom
                height: width
                fillMode: Image.PreserveAspectCrop
                source: AppSearch.getIconSource(appBtn.appId, "image-missing")
                sourceSize.width: 96
                sourceSize.height: 96
            }

            // Rendered at 3x the item's actual pixel size before the mask
            // is applied - these circles are only ~30px on screen, and at
            // that size the default 1:1 layer texture made the masked
            // edge (and the icon art scaled into it) look visibly grainy.
            // Supersampling here is cheap (still a tiny offscreen buffer)
            // and the GPU downsamples it back down when compositing.
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(appIconMask.width * 3, appIconMask.height * 3)
            layer.effect: GE.OpacityMask {
                maskSource: Rectangle {
                    width: appIconMask.width
                    height: appIconMask.height
                    radius: width / 2
                    antialiasing: true
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: mouseEvent => {
                if (mouseEvent.button === Qt.RightButton && (mouseEvent.modifiers & Qt.ControlModifier)) {
                    appBtn.togglePin()
                    return
                }
                if (!appBtn.running) {
                    if (mouseEvent.button === Qt.LeftButton) appBtn.desktopEntry?.execute()
                    return
                }
                const tls = appBtn.toplevels
                if (mouseEvent.button === Qt.MiddleButton || mouseEvent.button === Qt.RightButton) {
                    const focused = tls.find(t => t.activated) ?? tls[0]
                    focused.close()
                    return
                }
                const focused = tls.find(t => t.activated)
                if (focused && tls.length > 1) {
                    tls[(tls.indexOf(focused) + 1) % tls.length].activate()
                } else {
                    tls[0].activate()
                }
            }
        }

        // Hover-only pin/unpin badge - the actual, reliable way to
        // (un)pin now. Inset inside the icon's own bounds rather than
        // overhanging past its edge: the dock is only ~42px thick, so a
        // badge poking out past the icon would risk getting clipped by
        // the panel surface itself. Fades and pops in rather than the
        // hard visible-toggle it used to be - every other hover state in
        // this file eases in, this was the one thing that just snapped.
        Rectangle {
            opacity: appBtn.hovered ? 1 : 0
            scale: appBtn.hovered ? 1 : 0.7
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            width: 15
            height: 15
            radius: 7.5
            antialiasing: true
            anchors.top: parent.top
            anchors.right: parent.right
            color: ColorUtils.applyAlpha("#000000", 0.75)
            border.width: 1
            border.color: ColorUtils.applyAlpha(SMColors.fg, 0.4)

            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: 10
                text: appBtn.pinned ? "close" : "push_pin"
                color: SMColors.fg
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: appBtn.togglePin()
            }
        }

        WToolTip { text: appBtn.displayName }
    }

    // Built once whenever NiriService.windows changes (a plain array
    // reassignment, which happens on basically any window event -
    // opened, closed, focus changed, moved...), instead of each
    // workspace dot re-scanning the entire window list itself. That was
    // an O(workspaces * windows) linear-search repeated on every single
    // window event, redone independently by every dot in the Repeater
    // below - a Set lookup per dot is O(1) against one O(windows) build.
    readonly property var workspaceIdsWithWindows: new Set((NiriService.windows ?? []).map(w => w.workspace_id))

    // --- Workspace indicator + brightness/nightlight, pinned to the
    // dock's "start" edge (top when vertical, left when horizontal).
    Grid {
        id: topGroup
        anchors {
            top: !root.horizontal ? parent.top : undefined
            left: root.horizontal ? parent.left : undefined
            topMargin: !root.horizontal ? 24 : 0
            leftMargin: root.horizontal ? 24 : 0
            horizontalCenter: !root.horizontal ? parent.horizontalCenter : undefined
            verticalCenter: root.horizontal ? parent.verticalCenter : undefined
        }
        spacing: 16
        columns: root.horizontal ? -1 : 1
        rows: root.horizontal ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        GhostPill {
            padding: 6
            spacing: 8
            horizontal: root.horizontal

            DockArcGauge {
                icon: "light_mode"
                value: Brightness.getMonitorForScreen(root.screen)?.brightness ?? Brightness.monitors[0]?.brightness ?? 0
                onClicked: root.cycleBrightness()
                onWheel: delta => delta > 0 ? Brightness.increaseBrightness() : Brightness.decreaseBrightness()
            }
            DockArcGauge {
                icon: "bedtime"
                active: Hyprsunset.active
                onClicked: Hyprsunset.toggle()
            }
        }

        // Bare dots directly on the dock's blurred background - no extra
        // pill chrome layered on top of it.
        Grid {
            spacing: 9
            columns: root.horizontal ? -1 : 1
            rows: root.horizontal ? 1 : -1
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Repeater {
                model: NiriService.currentOutputWorkspaces

                delegate: Item {
                    id: wsDelegate
                    required property var modelData
                    readonly property bool active: modelData.is_active ?? modelData.is_focused ?? false
                    readonly property bool hasWindows: root.workspaceIdsWithWindows.has(wsDelegate.modelData.id)
                    readonly property bool hovered: wsMouse.containsMouse
                    readonly property int dotSize: 11
                    readonly property int activeLength: 26

                    implicitWidth: root.horizontal ? (wsDelegate.active ? activeLength : dotSize) : dotSize
                    implicitHeight: root.horizontal ? dotSize : (wsDelegate.active ? activeLength : dotSize)

                    // Without these, the active pill's own width/height
                    // Behaviors (below) would ease smoothly while Grid
                    // snapped every other dot straight to its new position
                    // in the same frame - the pill grew smoothly but its
                    // neighbors still visibly jumped.
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    scale: wsMouse.pressed ? 0.8 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.implicitWidth
                        height: parent.implicitHeight
                        radius: Math.min(width, height) / 2
                        antialiasing: true
                        color: wsDelegate.active ? SMColors.accent
                            : wsDelegate.hasWindows ? ColorUtils.applyAlpha(SMColors.fg, 0.7)
                            : wsDelegate.hovered ? ColorUtils.applyAlpha(SMColors.fg, 0.5)
                            : ColorUtils.applyAlpha(SMColors.fg, 0.3)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NiriService.switchToWorkspace(wsDelegate.modelData.idx)
                    }
                }
            }
        }
    }

    // --- Pinned launchers (in a soft pill, running or not) above the
    // currently-running, unpinned apps (bare on the dock's background - a
    // pill wrapper there read as clutter, not "a taskbar").
    readonly property var pinnedAppIds: (Config.options?.dock?.pinnedApps ?? []).map(id => id.toLowerCase())

    // Minecraft's window app_id ("Minecraft* 1.21.11", version-suffixed and
    // unstable) has no real desktop icon of its own - AppSearch's regex
    // substitution already points its icon at PrismLauncher's. Without this
    // grouping, the taskbar itself doesn't know they're related though: with
    // PrismLauncher pinned and both it and a Minecraft instance running,
    // they'd land in two separate slots wearing the exact same glyph, which
    // just reads as a duplicated/glitched icon instead of two related
    // windows sharing one launcher's identity.
    function taskbarGroupKey(appId) {
        return /Minecraft.*/.test(appId) ? "org.prismlauncher.prismlauncher" : appId.toLowerCase()
    }

    readonly property var pinnedApps: root.pinnedAppIds.map(pid => {
        const runningEntries = TaskbarApps.apps.filter(a => root.taskbarGroupKey(a.appId) === pid)
        return {
            appId: runningEntries[0]?.appId ?? pid,
            toplevels: runningEntries.reduce((acc, a) => acc.concat(a.toplevels), [])
        }
    })
    readonly property var unpinnedRunningApps: TaskbarApps.apps.filter(a => !root.pinnedAppIds.includes(root.taskbarGroupKey(a.appId)))

    // Ctrl+right-click any dock icon to pin/unpin it - see DockAppIcon's
    // togglePin signal. Mirrors TrayService's pin()/unpin() pattern
    // (Config.setNestedValue on a plain string list) just under the
    // dock's own config key.
    function isAppPinned(appId) {
        return root.pinnedAppIds.includes(appId.toLowerCase())
    }
    function pinApp(appId) {
        const pins = Config.options?.dock?.pinnedApps ?? []
        if (root.isAppPinned(appId)) return
        Config.setNestedValue("dock.pinnedApps", pins.concat([appId]))
    }
    function unpinApp(appId) {
        const pins = Config.options?.dock?.pinnedApps ?? []
        Config.setNestedValue("dock.pinnedApps", pins.filter(p => p.toLowerCase() !== appId.toLowerCase()))
    }
    function toggleAppPin(appId) {
        if (root.isAppPinned(appId)) root.unpinApp(appId)
        else root.pinApp(appId)
    }

    Grid {
        visible: root.pinnedApps.length > 0 || root.unpinnedRunningApps.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14
        columns: root.horizontal ? -1 : 1
        rows: root.horizontal ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        // A dim outline capsule rather than a filled tint - the filled
        // grey pill was landing at almost the same color as every icon's
        // own backplate behind it, so pinned vs. unpinned read as one
        // muddy grey mass instead of two distinct groups.
        GhostPill {
            visible: root.pinnedApps.length > 0
            padding: 6
            spacing: 6
            horizontal: root.horizontal
            fillColor: "transparent"
            borderWidth: 1
            borderColor: ColorUtils.applyAlpha(SMColors.fg, 0.25)

            Repeater {
                model: root.pinnedApps
                delegate: DockAppIcon {
                    required property var modelData
                    appId: modelData.appId
                    toplevels: modelData.toplevels
                    showBackplate: false
                    pinned: true
                    onTogglePin: root.toggleAppPin(appId)
                }
            }
        }

        Grid {
            visible: root.unpinnedRunningApps.length > 0
            spacing: 8
            columns: root.horizontal ? -1 : 1
            rows: root.horizontal ? 1 : -1
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Repeater {
                model: root.unpinnedRunningApps
                delegate: DockAppIcon {
                    required property var modelData
                    appId: modelData.appId
                    toplevels: modelData.toplevels
                    onTogglePin: root.toggleAppPin(appId)
                }
            }
        }
    }

    // --- Utility blobs, pinned to the dock's "end" edge (bottom when
    // vertical, right when horizontal) - volume bare, do-not-disturb/wifi/
    // bluetooth grouped in a pill, power bare on its own.
    Grid {
        anchors {
            bottom: !root.horizontal ? parent.bottom : undefined
            right: root.horizontal ? parent.right : undefined
            bottomMargin: !root.horizontal ? 14 : 0
            rightMargin: root.horizontal ? 14 : 0
            horizontalCenter: !root.horizontal ? parent.horizontalCenter : undefined
            verticalCenter: root.horizontal ? parent.verticalCenter : undefined
        }
        spacing: 14
        columns: root.horizontal ? -1 : 1
        rows: root.horizontal ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        DockArcGauge {
            icon: (Audio.sink?.audio.muted ?? false) ? "volume_off" : "volume_up"
            value: (Audio.sink?.audio.muted ?? false) ? 0 : Math.min(1, Audio.value)
            onClicked: root.cycleVolume()
            onRightClicked: Audio.toggleMute()
            onWheel: delta => delta > 0 ? Audio.incrementVolume() : Audio.decrementVolume()
        }

        GhostPill {
            padding: 6
            spacing: 10
            horizontal: root.horizontal

            DockFlatIcon {
                icon: Notifications.silent ? "notifications_off" : "notifications"
                active: Notifications.silent
                onClicked: Notifications.toggleSilent()
            }
            DockFlatIcon {
                icon: root.wifiEnabled ? "wifi" : "wifi_off"
                active: root.wifiEnabled
                onClicked: root.toggleWifi()
            }
            DockFlatIcon {
                icon: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                active: BluetoothStatus.enabled
                onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
            }
        }

        DockFlatIcon {
            icon: "power_settings_new"
            ringColor: ColorUtils.applyAlpha(SMColors.fg, 0.35)
            ringWidth: 1.5
            onClicked: GlobalStates.sessionOpen = true
        }
    }
}
