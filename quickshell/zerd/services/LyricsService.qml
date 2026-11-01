pragma Singleton

import QtQuick
import Quickshell

// No lyrics source in this shell: the now-playing card sees "no lyrics".
Singleton {
    readonly property string status: "none"
    readonly property var lyricsLines: []
    readonly property var slots: []
    function subscribe(): void {}
    function unsubscribe(): void {}
}
