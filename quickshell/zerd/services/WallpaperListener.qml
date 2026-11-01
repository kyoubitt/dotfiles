pragma Singleton

import QtQuick
import Quickshell

Singleton {
    function wallpaperUrlForScreen(screen: var): string { return Wallpapers.effectiveWallpaperUrl }
}
