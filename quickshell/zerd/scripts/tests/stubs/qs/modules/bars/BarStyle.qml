pragma Singleton
import QtQuick

// Test stand-in for the shell's BarStyle: only what the files under test read.
QtObject {
    readonly property color accent: Qt.rgba(0.83, 0.64, 0.45, 1)
    readonly property color onAccent: Qt.rgba(0.1, 0.08, 0.07, 1)
}
