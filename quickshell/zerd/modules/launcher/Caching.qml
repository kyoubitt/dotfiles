pragma Singleton
import QtQuick
import Quickshell

// Where the launcher keeps its files: the scripts next to it and a cache folder for the last tab.
QtObject {
    readonly property string qsDir: Quickshell.shellPath("modules")
    readonly property string zerdDir: Quickshell.shellPath("modules/bars/ilya")     // the shaders live with the bar parts
    function getCacheDir(name: string): string {
        const dir = Quickshell.env("HOME") + "/.cache/zerd-" + name
        Quickshell.execDetached(["mkdir", "-p", dir])
        return dir
    }
}
