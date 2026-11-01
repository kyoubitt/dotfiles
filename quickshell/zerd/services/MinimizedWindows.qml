pragma Singleton

import QtQuick
import Quickshell

// niri has no minimized state, so nothing is ever minimized. Kept so the
// floating dock's "restore" paths resolve.
Singleton {
    function countMinimizedForApp(appId: string): int { return 0 }
    function restoreLatestForApp(appId: string): void {}
    function isMinimized(windowId): bool { return false }
    function restore(windowId): void {}
}
