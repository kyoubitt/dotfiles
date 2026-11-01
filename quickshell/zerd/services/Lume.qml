pragma Singleton

import QtQuick
import Quickshell

// Stand-in for iNiR's Lume (wallpaper-luminance contrast solver). The vendored
// iRiS cards call it to pick legible veils and ink colours over a sampled
// region of the wallpaper; here every face sits on an opaque plate, so the
// seed colours are already legible and no sampling is needed.
Singleton {
    function mark(seed: color, level: real, spread: real, darkInk: bool, contrast: real): color { return seed }
    function frost(level: real, spread: real, materialSpread: real, base: color, ink: bool, contrast: real, floor: real): real { return 0.82 }
    function veil(level: real, spread: real, materialSpread: real, opaque: bool, ink: color, contrast: real, floor: real, ceiling: real): real { return 0.82 }
    function read(output: string, x: real, y: real, w: real, h: real): var { return null }
    function screenNamed(name: string): var { return null }
    function covered(output: string): bool { return false }
    function stack(under: color, over: color): color { return over }
    function plateOver(plate: color, alpha: real): color { return plate }
}
