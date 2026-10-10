pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wallust-driven palette for the widgets panel (modules/widgets/) -
// deliberately separate from SMColors (which is material-color-generated
// off the bar's own pipeline) since the widgets panel was designed against
// wallust's own color roles specifically.
Singleton {
    id: root

    // Translucent again - the opaque phase was a workaround for
    // WlrLayer.Bottom not alpha-compositing correctly on this system. The
    // panel has been back on WlrLayer.Top since (confirmed correct
    // blending there via pixel sampling), so there's no reason to stay
    // opaque. These specific alpha values (not the ~0.32-0.40 "glassmorphism
    // spec" numbers) are the ones already proven legible against this
    // wallpaper earlier this session - lower reads as washed-out gray, not
    // a usable backdrop for the text on top of it.
    property color bgBase: alpha("#1A1412", 0.62)
    property color bgCard: alpha("#1E1614", 0.68)
    property color textPrimary: "#E0C097"
    property color textSecondary: "#A08A75"
    property color accent: "#D4A373"
    // Translucent warm-tinted hairline, not a flat gray - reads as part
    // of the glass rather than a hard outline.
    property color cardBorder: alpha("#E0C097", 0.13)
    // Opaque dark text for content sitting on a solid accent fill (e.g.
    // the calendar's "today" circle) - bgBase itself is translucent, so
    // using it directly there would be nearly invisible against the
    // accent behind it.
    property color textOnAccent: "#1A1412"

    // Manual hex parsing rather than Qt.color(), which isn't a
    // guaranteed-available global - this only depends on Qt.rgba().
    function alpha(hex, a) {
        const h = hex.replace("#", "")
        const r = parseInt(h.substring(0, 2), 16) / 255
        const g = parseInt(h.substring(2, 4), 16) / 255
        const b = parseInt(h.substring(4, 6), 16) / 255
        return Qt.rgba(r, g, b, a)
    }

    function applyColors(data) {
        try {
            const special = data.special ?? {}
            const colors = data.colors ?? {}
            if (special.background) {
                root.bgBase = alpha(special.background, 0.62)
                root.bgCard = alpha(special.background, 0.68)
            }
            if (special.foreground) root.textPrimary = special.foreground
            if (colors.color8) root.textSecondary = colors.color8
            if (colors.color4) root.accent = colors.color4
        } catch (e) {
            console.warn("[WallustTheme] Failed to apply colors:", e)
        }
    }

    FileView {
        id: fv
        path: `${Quickshell.env("HOME")}/.cache/wallust/colors.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyColors(JSON.parse(fv.text()))
    }
}
