pragma Singleton
import QtQuick
import Quickshell
import qs.services as Svc

QtObject {
    readonly property string layout: String(Svc.NiriService.keyboardLayoutNames?.[Svc.NiriService.currentKeyboardLayoutIndex] ?? "US").slice(0, 2).toUpperCase()
    readonly property bool ready: (Svc.NiriService.keyboardLayoutNames?.length ?? 0) > 0
    function subscribe() {}
    function unsubscribe() {}
    function switchNext() {
        Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
    }
}
