pragma Singleton
import QtQuick

QtObject {
    property var occupiedByOutput: ({})
    property int tagCount: 0
    function activeIndexFor(outputName) { return 0; }
    function isOccupied(outputName, index) { return false; }
    function subscribe() {}
    function unsubscribe() {}
}
