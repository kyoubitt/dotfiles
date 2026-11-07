pragma Singleton
import QtQuick

QtObject {
    property bool isRecording: false
    property int recSeconds: 0
    readonly property string recTimeFormatted: String(Math.floor(recSeconds / 60)).padStart(2, "0") + ":" + String(recSeconds % 60).padStart(2, "0")
    function subscribe() {}
    function unsubscribe() {}
}
