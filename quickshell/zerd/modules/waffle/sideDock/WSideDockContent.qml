pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray
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
    Component.onCompleted: wifiStatusProc.running = true

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
        // Plain wrap-around cycle through the full preset range. Safe now
        // that 100% no longer sends the panel's literal max raw value
        // (see Brightness.qml's syncBrightness) - it used to look like the
        // screen going dark specifically at "max", not a wraparound issue.
        mon.setBrightness(root.nextPreset(root.brightnessPresets, mon.brightness))
    }

    function cycleVolume() {
        if (Audio.sink?.audio.muted) Audio.sink.audio.muted = false
        Audio.setSinkVolume(root.nextPreset(root.volumePresets, Audio.value))
    }

    // No shared backdrop behind the whole bar anymore - it was a live
    // blurred+darkened crop of the wallpaper (see git history if this
    // needs resurrecting), but even after fixing its size/shape it still
    // read as too strong a visual element in its own right. The individual
    // GhostPill/battery-pill backgrounds already carry enough structure on
    // their own; the gaps between them are just the plain wallpaper now.

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
        // A black fill (even at high alpha) is invisible against a wallpaper
        // patch that's already near-black - there's no contrast for a dark
        // overlay to add, however opaque it gets. A light fill (off
        // SMColors.fg, the dock's light foreground tone) instead always
        // reads as a distinct lighter patch no matter how dark the backdrop
        // is, which a dark fill fundamentally can't guarantee. Paired with
        // a drop shadow so the pill also separates itself on a *light*
        // patch of wallpaper, where a faint fill alone would wash out.
        property color fillColor: ColorUtils.applyAlpha(SMColors.fg, 0.14)
        property color borderColor: ColorUtils.applyAlpha(SMColors.fg, 0.35)
        property real borderWidth: 1

        implicitWidth: inner.implicitWidth + padding * 2
        implicitHeight: inner.implicitHeight + padding * 2

        Rectangle {
            id: pillBg
            anchors.fill: parent
            radius: (pill.horizontal ? height : width) / 2
            antialiasing: true
            color: pill.fillColor
            border.width: pill.borderWidth
            border.color: pill.borderColor

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.55)
                shadowBlur: 0.5
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }
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
        // Set when this icon represents a tray-only app with no open
        // window (Steam/Discord/etc. minimized to the system tray) - see
        // TrayService.qml. Changes both the click behavior and the resting
        // opacity below.
        property var trayItem: null
        // Needed only for the right-click context menu below, which lives
        // in its own top-level Scope/PanelWindow and has to be told which
        // screen to open on - nothing else on this icon touches it.
        property var screen: null
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
        // Rounded-square rather than a full circle - a squircle app tile
        // (macOS/GNOME-style) instead of the old circular mask, shared by
        // the icon mask, its backplate outline, and its active-state glow
        // so all three stay one consistent shape.
        readonly property real iconCornerRatio: 0.28
        readonly property var desktopEntry: DesktopEntries.byId(appBtn.appId) ?? DesktopEntries.heuristicLookup(appBtn.appId)
        readonly property string displayName: appBtn.desktopEntry?.name ?? appBtn.appId
        readonly property bool hovered: mouse.containsMouse
        // Pin/unpin. Plain click on the small hover badge below - a
        // Ctrl+right-click gesture used to be the only way to do this,
        // but that's an easy combo to botch (a trackpad's right-click
        // gesture doesn't always carry the modifier through cleanly) and
        // it failed completely silently either way. Still left as a quick
        // fallback below.
        signal togglePin()

        // Opens the right-click context menu near this icon. mapToItem(null, ...)
        // maps into this icon's own containing Window (the dock's own
        // PanelWindow) rather than full multi-monitor desktop coordinates -
        // the context menu's PanelWindow is anchored to fill that exact
        // same screen edge-to-edge, so that window-local point is directly
        // usable there without any cross-window coordinate translation.
        function openContextMenu(mouseEvent) {
            const p = appBtn.mapToItem(null, mouseEvent.x, mouseEvent.y)
            GlobalStates.dockContextMenuAppId = appBtn.appId
            GlobalStates.dockContextMenuToplevels = appBtn.toplevels
            GlobalStates.dockContextMenuScreen = appBtn.screen
            GlobalStates.dockContextMenuAnchorX = p.x
            GlobalStates.dockContextMenuAnchorY = p.y
            GlobalStates.dockContextMenuOpen = true
        }

        implicitWidth: 33
        implicitHeight: 33
        // Three resting states: fully on (focused/has a window), fully
        // dim (not running at all), and a middle ground for "running in
        // the background with no window" - distinct from either extreme.
        opacity: appBtn.running ? 1 : (appBtn.trayItem ? 0.75 : 0.45)
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        scale: mouse.pressed ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        // Always-on backplate, independent of active state - without it,
        // a monochrome or pale icon (folder, the hex launcher glyph)
        // washes out against a light patch of wallpaper. A thin outline
        // ring rather than a filled hazy circle - matches the pinned
        // pill's own outline treatment instead of competing with it, and
        // reads as crisp lines instead of another soft blob stacked on
        // top of the icon underneath. Rounded-square to match the icon
        // mask's own shape below - a circular outline around a squircle
        // icon read as two mismatched shapes stacked on each other.
        Rectangle {
            visible: appBtn.showBackplate
            anchors.centerIn: parent
            width: appIconMask.width + 8
            height: width
            radius: width * appBtn.iconCornerRatio
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
        // (nothing showed, no errors). Sized off appIconMask (the actual
        // visible circle after clipping), not appIcon (the bigger,
        // unclipped zoomed source image behind it) - sizing off the latter
        // made this circle overhang well past the icon's real edge, so its
        // own hard boundary showed as a second ring next to the backplate
        // ring instead of hiding behind the icon like a proper glow.
        Rectangle {
            visible: appBtn.active
            anchors.centerIn: parent
            width: appIconMask.width * 0.9
            height: width
            radius: width * appBtn.iconCornerRatio
            color: SMColors.accent

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: SMColors.accent
                shadowBlur: 0.7
                shadowOpacity: 0.45
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }
        }

        // Every icon cropped to a rounded square (a squircle app tile,
        // like macOS/GNOME dock icons) regardless of its own art's shape.
        // Most icon themes bake in transparent padding around the actual
        // glyph (a folder, a hexagon...), so masking the image at its
        // natural size only clips that empty margin into the mask shape -
        // the visible glyph inside still reads as whatever shape it was
        // drawn as. Rendering the image oversized
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
                // Tray-derived icons (appBtn.trayItem set) go through
                // TrayService.getSafeIcon first - a tray item's own
                // self-reported icon name/path is sometimes unresolvable
                // (e.g. Spotify's points outside the system icon theme
                // dirs entirely), and that service's problematicApps table
                // already carries the right fixedIcon override for those.
                // Everything else keeps using AppSearch directly, same as
                // always.
                source: appBtn.trayItem
                    ? AppSearch.resolveIcon(TrayService.getSafeIcon(appBtn.trayItem), "image-missing")
                    : AppSearch.getIconSource(appBtn.appId, "image-missing")
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
                    radius: width * appBtn.iconCornerRatio
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
                // Tray-derived icon (no window to focus/close/menu) - left
                // click focuses the app's existing window if TrayService
                // can find one, otherwise launches/restores it. Right and
                // middle click are no-ops here; there's nothing for them
                // to do yet.
                if (appBtn.trayItem) {
                    if (mouseEvent.button === Qt.LeftButton) {
                        if (!TrayService.smartToggle(appBtn.trayItem)) appBtn.trayItem.activate()
                    }
                    return
                }
                // Right-click now opens a menu (Pin/Unpin, Close) instead
                // of instantly closing the focused window - that instant
                // close had no confirmation and was easy to trigger by
                // accident. Middle-click is still the fast, un-menu'd way
                // to close a window, unchanged.
                if (mouseEvent.button === Qt.RightButton) {
                    appBtn.openContextMenu(mouseEvent)
                    return
                }
                if (!appBtn.running) {
                    if (mouseEvent.button === Qt.LeftButton) appBtn.desktopEntry?.execute()
                    return
                }
                const tls = appBtn.toplevels
                if (mouseEvent.button === Qt.MiddleButton) {
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

        // Up to 3 short segments under the icon when more than one window
        // of this app is open - the same "how many windows" signal the
        // real Windows 11 taskbar gives per icon. An overlay past the
        // icon's own bottom edge rather than added layout space (like the
        // hover-badge above already does), so it doesn't need to grow this
        // icon's implicitWidth/Height or care which edge the dock is on.
        Row {
            visible: appBtn.toplevels.length > 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 1
            spacing: 2

            Repeater {
                model: Math.min(appBtn.toplevels.length, 3)
                delegate: Rectangle {
                    width: 6
                    height: 2
                    radius: 1
                    antialiasing: true
                    color: appBtn.active ? SMColors.accent : ColorUtils.applyAlpha(SMColors.fg, 0.6)
                }
            }
        }
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
            topMargin: !root.horizontal ? 28 : 0
            leftMargin: root.horizontal ? 28 : 0
            horizontalCenter: !root.horizontal ? parent.horizontalCenter : undefined
            verticalCenter: root.horizontal ? parent.verticalCenter : undefined
        }
        spacing: 20
        columns: root.horizontal ? -1 : 1
        rows: root.horizontal ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        GhostPill {
            padding: 7
            spacing: 10
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
            spacing: 11
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
    readonly property var pinnedAppIds: DockPins.pinnedAppIds

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
        const runningEntries = TaskbarApps.apps.filter(a => a && root.taskbarGroupKey(a.appId) === pid)
        return {
            appId: runningEntries[0]?.appId ?? pid,
            toplevels: runningEntries.reduce((acc, a) => acc.concat(a.toplevels), [])
        }
    })
    // TaskbarApps.apps can momentarily hold a stale/null entry mid-recompute
    // (e.g. right as pinnedApps changes under it, which now happens a lot
    // more often via the pin picker's rapid pin/unpin) - guard rather than
    // let a transient null blow up this whole binding.
    readonly property var unpinnedRunningApps: TaskbarApps.apps.filter(a => a && !root.pinnedAppIds.includes(root.taskbarGroupKey(a.appId)))

    // Apps running in the background with no open window at all - Steam,
    // Discord, etc. minimized to the system tray. TrayService.problematicApps
    // is also the only reliable way to tell a real app's tray icon apart
    // from an applet (NetworkManager, Bluetooth...) since the tray protocol
    // itself carries no such distinction - so only tray items matching that
    // table ever show here, not every random tray icon.
    readonly property var backgroundApps: {
        const result = []
        const seen = new Set()
        for (const item of SystemTray.items.values) {
            if (!item || !item.id) continue
            // Applets (network, bluetooth, volume...) are Hardware or
            // SystemServices in the tray protocol; actual apps are
            // ApplicationStatus or Communications. Only the latter get
            // their own background slot.
            if (item.category === Category.Hardware || item.category === Category.SystemServices) continue
            // Passive means the app asked to be hidden.
            if (item.status === Status.Passive) continue
            // Known apps keep their curated launch command and matching
            // patterns; anything else is shown under its own tray id/title.
            const known = TrayService.getProblematicAppInfo(item)
            const info = known ?? {
                launch: item.id,
                matches: [item.id, item.title ?? ""].filter(m => m.length > 0)
            }
            const key = info.launch.toLowerCase()
            if (seen.has(key)) continue
            // Each match pattern checked against the pinned list, and the
            // running windows, so a pinned or already-open app never shows
            // up here a second time.
            const isPinned = root.pinnedAppIds.some(pid => info.matches.some(m => pid.includes(m.toLowerCase())))
            if (isPinned) continue
            const hasWindow = TaskbarApps.apps.some(a => a && info.matches.some(m => a.appId.toLowerCase().includes(m.toLowerCase())))
            if (hasWindow) continue
            seen.add(key)
            result.push({ appId: info.launch, trayItem: item })
        }
        return result
    }

    // Ctrl+right-click any dock icon to pin/unpin it - see DockAppIcon's
    // togglePin signal. Actual pin state lives in DockPins (services/) now,
    // not here - the pin picker and right-click menu below are separate
    // top-level Scopes that need the same read/write surface this root
    // Item used to own alone.
    function isAppPinned(appId) { return DockPins.isAppPinned(appId) }
    function pinApp(appId) { DockPins.pinApp(appId) }
    function unpinApp(appId) { DockPins.unpinApp(appId) }
    function toggleAppPin(appId) { DockPins.toggleAppPin(appId) }

    // Continues the left-to-right chain from topGroup when horizontal
    // (see its comment above) instead of centering on root's own width,
    // which would read root's width back while root's width is itself
    // derived from this chain.
    Grid {
        id: appsGroup
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18
        columns: root.horizontal ? -1 : 1
        rows: root.horizontal ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        // A dim outline capsule rather than a filled tint - the filled
        // grey pill was landing at almost the same color as every icon's
        // own backplate behind it, so pinned vs. unpinned read as one
        // muddy grey mass instead of two distinct groups. Always visible
        // now (even with zero pins) since it also hosts the "add pin"
        // trigger - that needs to stay reachable, not disappear along with
        // the last pinned icon.
        GhostPill {
            padding: 7
            spacing: 6
            horizontal: root.horizontal
            fillColor: "transparent"
            borderWidth: 1
            borderColor: ColorUtils.applyAlpha(SMColors.fg, 0.35)

            Repeater {
                model: root.pinnedApps
                delegate: DockAppIcon {
                    required property var modelData
                    appId: modelData.appId
                    toplevels: modelData.toplevels
                    screen: root.screen
                    showBackplate: false
                    pinned: true
                    onTogglePin: root.toggleAppPin(appId)
                }
            }

            // Opens the searchable pin picker (WSideDockPinPicker) - the
            // only way to pin an app that isn't already running, since
            // every DockAppIcon's own pin badge only exists for apps that
            // already have a dock icon to hover.
            DockFlatIcon {
                icon: "add"
                baseSize: 20
                hoverSize: 26
                onClicked: {
                    GlobalStates.pinPickerScreen = root.screen
                    GlobalStates.pinPickerOpen = true
                }
            }
        }

        Grid {
            visible: root.unpinnedRunningApps.length > 0 || root.backgroundApps.length > 0
            spacing: 9
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
                    screen: root.screen
                    onTogglePin: root.toggleAppPin(appId)
                }
            }

            Repeater {
                model: root.backgroundApps
                delegate: DockAppIcon {
                    required property var modelData
                    appId: modelData.appId
                    trayItem: modelData.trayItem
                    screen: root.screen
                    onTogglePin: root.toggleAppPin(appId)
                }
            }
        }
    }

    // --- Utility blobs - volume bare, do-not-disturb/wifi/bluetooth
    // grouped in a pill, power bare on its own. Pinned to the dock's
    // "end" edge - bottom when vertical, right when horizontal.
    Grid {
        anchors {
            bottom: !root.horizontal ? parent.bottom : undefined
            right: root.horizontal ? parent.right : undefined
            bottomMargin: !root.horizontal ? 18 : 0
            rightMargin: root.horizontal ? 18 : 0
            horizontalCenter: !root.horizontal ? parent.horizontalCenter : undefined
            verticalCenter: root.horizontal ? parent.verticalCenter : undefined
        }
        spacing: 18
        columns: root.horizontal ? -1 : 1
        rows: root.horizontal ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        // Only on laptops - Battery.available reflects UPower's own
        // isLaptopBattery check, so this is simply absent on a desktop.
        // A plain icon+percentage stack rather than DockArcGauge's ring -
        // the actual number reads faster than an arc for battery
        // specifically. Wrapped in the same GhostPill capsule every other
        // control here uses rather than floating bare - without a
        // boundary it was the one item that didn't read as "a control"
        // next to the ringed/backplated ones around it.
        // A standalone Rectangle rather than GhostPill - GhostPill's
        // `content` alias reparents any child into its own internal Grid,
        // which doesn't leave a clean way to add a plain click handler
        // (a MouseArea declared inside it becomes a third grid row, not an
        // overlay), and wrapping GhostPill in an outer Item to hold that
        // MouseArea instead turned into an implicit-size forwarding chain
        // fragile enough it was rendering broken - as the first item in
        // this Grid, that took every item after it down with it. Same
        // visual recipe as GhostPill, just self-contained.
        Rectangle {
            id: batteryPill
            visible: Battery.available
            implicitWidth: battContent.implicitWidth + 12
            implicitHeight: battContent.implicitHeight + 12
            radius: (root.horizontal ? height : width) / 2
            antialiasing: true
            // Same light-fill recipe as GhostPill now, not a black overlay -
            // see its comment. Kept as its own Rectangle rather than
            // switched to GhostPill itself (see the comment above this one
            // on why).
            color: ColorUtils.applyAlpha(SMColors.fg, 0.14)
            border.width: 1
            border.color: ColorUtils.applyAlpha(SMColors.fg, 0.35)

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.55)
                shadowBlur: 0.5
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }

            property bool expanded: false
            // Under 50%, not "not at 100%" - that first cut read as red
            // almost all the time, which isn't the "needs attention" this
            // is supposed to signal.
            readonly property bool isLow: Battery.percentage < 0.50
            readonly property color statusColor: batteryPill.isLow ? "#E58C8C" : "#8BC34A"

            // "3h 42m until full/empty" - click to reveal. UPower reports
            // both in seconds; 0 means "unknown" (e.g. just plugged in,
            // still calculating), so hide the line rather than show a
            // bogus "0m".
            readonly property real detailSeconds: Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty
            function formattedDetail() {
                const mins = Math.round(batteryPill.detailSeconds / 60)
                const h = Math.floor(mins / 60)
                const m = mins % 60
                const duration = h > 0 ? `${h}h ${m}m` : `${m}m`
                return Battery.isCharging
                    ? Translation.tr("%1 until full").arg(duration)
                    : Translation.tr("%1 until empty").arg(duration)
            }

            Grid {
                id: battContent
                anchors.centerIn: parent
                spacing: 1
                columns: root.horizontal ? -1 : 1
                rows: root.horizontal ? 1 : -1
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                // Drawn as an actual landscape battery shape (body + fill
                // bar + terminal nub) rather than a Material Symbol glyph -
                // those are drawn upright/portrait, and a naive 90°
                // rotation kept flipping the little details (the charge
                // notches, the nub) into the wrong place. Plain shapes give
                // exact control over the sideways look instead.
                Item {
                    id: battShape
                    // Bumped from 20x10 - at the old size the fill bar and
                    // border read as a muddy sliver with almost no room for
                    // the charge notch between them.
                    implicitWidth: 25
                    implicitHeight: 13

                    Rectangle {
                        id: battBody
                        width: parent.width - battNub.width - 1
                        height: parent.height
                        radius: 3
                        antialiasing: true
                        color: "transparent"
                        border.width: 1.4
                        border.color: batteryPill.statusColor

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 1.5
                            antialiasing: true
                            color: "transparent"
                            clip: true

                            Rectangle {
                                width: parent.width * Math.max(0.08, Battery.percentage)
                                height: parent.height
                                radius: 1.5
                                antialiasing: true
                                color: batteryPill.statusColor
                                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            }
                        }

                        // Charging had no visual signal at all before this -
                        // a bolt cut into the fill, in the body's own outline
                        // color so it reads against either an empty or full
                        // bar without needing its own background chip.
                        MaterialSymbol {
                            visible: Battery.isCharging
                            anchors.centerIn: parent
                            iconSize: 9
                            text: "bolt"
                            color: SMColors.bg

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: batteryPill.statusColor
                                shadowBlur: 0.8
                                shadowOpacity: 0.9
                                shadowVerticalOffset: 0
                                shadowHorizontalOffset: 0
                            }
                        }
                    }

                    Rectangle {
                        id: battNub
                        width: 2.5
                        height: 5
                        radius: 1.2
                        antialiasing: true
                        color: batteryPill.statusColor
                        anchors.left: battBody.right
                        anchors.leftMargin: 1
                        anchors.verticalCenter: battBody.verticalCenter
                    }
                }
                Text {
                    text: Math.round(Battery.percentage * 100) + "%"
                    font.pixelSize: 10
                    color: batteryPill.isLow ? batteryPill.statusColor : ColorUtils.applyAlpha(SMColors.fg, 0.85)
                }
                Text {
                    visible: batteryPill.expanded && batteryPill.detailSeconds > 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    text: batteryPill.formattedDetail()
                    font.pixelSize: 9
                    color: ColorUtils.applyAlpha(SMColors.fg, 0.65)
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: batteryPill.expanded = !batteryPill.expanded
            }
        }

        DockArcGauge {
            icon: (Audio.sink?.audio.muted ?? false) ? "volume_off" : "volume_up"
            value: (Audio.sink?.audio.muted ?? false) ? 0 : Math.min(1, Audio.value)
            onClicked: root.cycleVolume()
            onRightClicked: Audio.toggleMute()
            onWheel: delta => delta > 0 ? Audio.incrementVolume() : Audio.decrementVolume()
        }

        GhostPill {
            padding: 7
            spacing: 12
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
