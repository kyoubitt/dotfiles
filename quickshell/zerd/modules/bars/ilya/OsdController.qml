pragma Singleton
import QtQuick

QtObject {
    property bool isFullscreen: false
    property var screen: null
    property int sysBrightness: 0
    property string brightnessBackend: ""
}
