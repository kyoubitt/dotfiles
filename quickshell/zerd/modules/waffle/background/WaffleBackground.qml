pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.waffle.startMenu
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: panelRoot
        required property var modelData

        // Waffle background config
        readonly property var wBg: Config.options.waffles?.background ?? {}
        readonly property var wEffects: wBg.effects ?? {}

        // Wallpaper source
        readonly property string wallpaperSource: {
            if (wBg.useMainWallpaper ?? true) return Config.options.background.wallpaperPath;
            return wBg.wallpaperPath || Config.options.background.wallpaperPath;
        }

        readonly property string wallpaperUrl: {
            const path = wallpaperSource;
            if (!path) return "";
            if (path.startsWith("file://")) return path;
            return "file://" + path;
        }

        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:wBackground"
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // Hide when fullscreen
        property bool hasFullscreenWindow: {
            if (CompositorService.isNiri && NiriService.windows) {
                return NiriService.windows.some(w => w.is_focused && w.is_fullscreen)
            }
            return false
        }
        
        // Hide wallpaper (show only backdrop for overview)
        readonly property bool backdropOnly: wBg.backdrop?.hideWallpaper ?? false
        
        readonly property bool overviewBackdropActive: {
            const backdrop = wBg.backdrop ?? {};
            return (backdrop.enable ?? false) && NiriService.inOverview;
        }

        visible: !backdropOnly
            && !overviewBackdropActive
            && (GlobalStates.screenLocked || !hasFullscreenWindow || !(wBg.hideWhenFullscreen ?? true))

        // Dynamic focus based on windows
        property bool hasWindowsOnCurrentWorkspace: {
            try {
                if (CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.windows && NiriService.workspaces) {
                    const allWs = Object.values(NiriService.workspaces);
                    if (!allWs || allWs.length === 0) return false;
                    const currentNumber = NiriService.getCurrentWorkspaceNumber();
                    const currentWs = allWs.find(ws => ws.idx === currentNumber);
                    if (!currentWs) return false;
                    return NiriService.windows.some(w => w.workspace_id === currentWs.id);
                }
                return false;
            } catch (e) { return false; }
        }

        property bool focusWindowsPresent: !GlobalStates.screenLocked && hasWindowsOnCurrentWorkspace
        property real focusPresenceProgress: focusWindowsPresent ? 1 : 0
        Behavior on focusPresenceProgress {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Blur progress
        property real blurProgress: {
            const blurEnabled = (wEffects.enableBlur ?? false);
            const blurRadius = Number(wEffects.blurRadius) || 32;
            if (!blurEnabled || blurRadius <= 0) return 0;
            
            const blurStatic = Math.max(0, Math.min(100, Number(wEffects.blurStatic) || 0));
            const dynamicPart = (100 - blurStatic) * focusPresenceProgress;
            return (blurStatic + dynamicPart) / 100;
        }

        Item {
            anchors.fill: parent
            clip: true

            Image {
                id: wallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: panelRoot.wallpaperUrl
                asynchronous: true
                cache: true
                sourceSize.width: panelRoot.width
                sourceSize.height: panelRoot.height

                layer.enabled: Appearance.effectsEnabled && panelRoot.blurProgress > 0
                layer.effect: MultiEffect {
                    source: wallpaper
                    anchors.fill: wallpaper
                    blurEnabled: true
                    blur: panelRoot.blurProgress
                    blurMax: Number(panelRoot.wEffects.blurRadius) || 32
                }
            }

            // Dim overlay
            Rectangle {
                anchors.fill: parent
                color: {
                    if (typeof NiriService !== "undefined" && NiriService.inOverview) {
                        return Qt.rgba(0, 0, 0, 0.45);
                    }
                    const baseN = Number(panelRoot.wEffects.dim) || 0;
                    const dynN = Number(panelRoot.wEffects.dynamicDim) || 0;
                    const extra = panelRoot.focusPresenceProgress > 0 ? dynN * panelRoot.focusPresenceProgress : 0;
                    const total = Math.max(0, Math.min(100, baseN + extra));
                    return Qt.rgba(0, 0, 0, total / 100);
                }
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        // Desktop time widget - drawn as a sibling *inside this same
        // surface*, after the wallpaper/dim layer, so it's guaranteed to be
        // on top of them. A separate PanelWindow at Bottom layer (the
        // previous approach) raced against this surface for stacking order
        // within the layer with no reliable winner - niri doesn't order
        // same-layer surfaces deterministically across reloads. Being part
        // of this surface also means it inherits all of wBackground's
        // existing visibility logic (hidden on fullscreen/overview/lock)
        // for free, instead of needing its own NiriService.inOverview check.
        Column {
            id: timeWidget
            readonly property var wRail: Config.options.waffles?.widgetsPanel ?? {}
            visible: wRail.enable ?? true
            // Top area, not dead-center - wallpaper subjects tend to sit
            // mid-to-lower frame (portraits, landscapes, characters), so
            // this stays clear of them regardless of what's set.
            anchors.top: parent.top
            anchors.topMargin: 90
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            // Plain white, not SMColors.fg - that theme color comes from
            // the *main* configured wallpaper (applycolor.sh), which isn't
            // necessarily this surface's own wallpaper, so it has no real
            // relationship to what's actually on screen here and can
            // clash badly (a warm/cool tinted fg blended translucently
            // over a saturated background reads as a muddy off-color, not
            // a clean veil). White never carries a hue of its own to
            // clash with, and it's what the original reference (and the
            // kde_modernclock/Rainmeter "Mond" skin it's from) both use.
            // The glow below - not this color - is what guarantees
            // contrast against arbitrary wallpaper brightness.
            readonly property color textColor: "#FFFFFF"

            // Tight, zero-offset glow so the text holds contrast on any
            // wallpaper brightness - a wide blur reads as a faint haze on
            // light wallpapers, so this keeps the radius small and
            // opacity high, centered rather than a directional shadow.
            component GlowText: Text {
                // QtRendering, not NativeRendering - NativeRendering's
                // subpixel (RGB) antialiasing is meant for direct-to-screen
                // compositing. Captured into an offscreen texture for
                // layer.effect below, that RGB fringing bakes in as
                // visible color fringes around every glyph instead of
                // being corrected by the screen. QtRendering is
                // grayscale-only and layer-safe.
                renderType: Text.QtRendering
                layer.enabled: Appearance.effectsEnabled
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.95
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    shadowBlur: 0.4
                    blurMax: 8
                }
            }

            // Big tracked-out day name, e.g. "TUESDAY" - traced the
            // reference image back to Prayag2/kde_modernclock (a KDE
            // Plasma widget cloning the Rainmeter "Mond" skin), which
            // draws this with the free "Anurati" display font. Same font
            // file, same sizing/tracking as that widget's defaults.
            GlowText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale().toString(DateTime.clock.date, "dddd").toUpperCase()
                // Solid, not translucent - translucent looked closer to
                // the reference over a dark/desaturated sky, but blended
                // against a saturated background (teal, etc.) partial
                // alpha desaturates toward the background hue instead of
                // reading as an elegant ghost - it just looks murky. Full
                // opacity avoids that regardless of wallpaper color; the
                // glow still keeps it soft rather than harsh.
                color: timeWidget.textColor
                font.family: "Anurati"
                font.pixelSize: 52
                font.letterSpacing: 12
            }

            // Date line, e.g. "11 AUG 2026" - Poppins, same as the source.
            GlowText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale().toString(DateTime.clock.date, "d MMM yyyy").toUpperCase()
                color: timeWidget.textColor
                // Poppins Medium, not Regular - same reason as the top
                // bar's StatText (see WTopBarContent.qml): Regular reads
                // too thin/washed-out at small sizes next to bolder text.
                font.family: "Poppins Medium"
                font.pixelSize: 18
                font.letterSpacing: 2.5
            }

            // Time line, flanked by dashes, e.g. "- 23:33 -"
            GlowText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "- " + DateTime.time + " -"
                color: timeWidget.textColor
                font.family: "Poppins Medium"
                font.pixelSize: 18
                font.letterSpacing: 2.5
            }
        }
    }
}
