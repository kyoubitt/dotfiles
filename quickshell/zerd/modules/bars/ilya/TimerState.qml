pragma Singleton
import QtQuick

QtObject {
    property var entries: []
    readonly property bool isActive: entries.length > 0
}
