pragma Singleton
import QtQuick
import Quickshell

QtObject {
    readonly property string serpantinumDir: Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
    readonly property string qsDir: serpantinumDir
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp") + "/zerd-bar"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") ?? ((Quickshell.env("HOME") ?? "") + "/.cache")) + "/zerd-bar"
    function getCacheDir(name) {
        return cacheDir + "/" + name;
    }
}
