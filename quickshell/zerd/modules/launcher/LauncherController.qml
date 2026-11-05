pragma Singleton
import QtQuick
import Quickshell
import qs

// Open state of the launcher: the shell's own search flag, so the `search toggle|open|close` IPC keeps working.
QtObject {
    readonly property bool isVisible: GlobalStates.searchOpen
    readonly property var screen: Quickshell.screens.find(s => s.name === GlobalStates.focusedScreen?.name) ?? Quickshell.screens[0]
    function hide(): void { GlobalStates.searchOpen = false }
    function show(): void { GlobalStates.searchOpen = true }
}
