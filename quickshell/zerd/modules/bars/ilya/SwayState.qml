pragma Singleton
import QtQuick

QtObject {
    property var occupiedMap: ({})
    function activeIndexFor(outputName) { return 0; }
    function focusWorkspace(index) {}
    function subscribe() {}
    function unsubscribe() {}
}
