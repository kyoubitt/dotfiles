pragma Singleton
import QtQuick

QtObject {
    readonly property bool isReady: true
    readonly property string currentLang: "en"
    readonly property string qtLocaleName: "en_US"
    readonly property bool rtl: false
    readonly property int layoutDirection: Qt.LeftToRight
    readonly property int textAlignment: Text.AlignLeft
    signal languageChanged()
    function t(key, fallback) {
        return fallback !== undefined ? fallback : key;
    }
}
