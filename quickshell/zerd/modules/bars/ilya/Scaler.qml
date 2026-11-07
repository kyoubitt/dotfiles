pragma Singleton
import QtQuick

QtObject {
    property real uiScale: 1.0
    property real baseScale: uiScale
    function s(val) {
        return val;
    }
}
