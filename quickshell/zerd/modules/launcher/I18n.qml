pragma Singleton
import QtQuick

// The launcher asks for translated strings; this shell is English only, so it gets the fallback text.
QtObject {
    readonly property bool rtl: false
    readonly property int textAlignment: Text.AlignLeft
    readonly property int layoutDirection: Qt.LeftToRight
    function t(key: string, fallback: string): string { return fallback !== undefined ? fallback : key }
}
