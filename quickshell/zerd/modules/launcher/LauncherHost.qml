import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Keeps the launcher window around only while the menu is open, and answers the `search` IPC.
Scope {
    id: root
    LazyLoader {
        active: GlobalStates.searchOpen
        Launcher {}
    }
    IpcHandler {
        target: "search"
        function toggle(): void { GlobalStates.searchOpen = !GlobalStates.searchOpen }
        function close(): void { GlobalStates.searchOpen = false }
        function open(): void { GlobalStates.searchOpen = true }
    }
}
