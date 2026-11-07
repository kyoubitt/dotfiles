pragma Singleton
import QtQuick

QtObject {
    function playSfx(name) {}
    function stopSfx(handle) {}
    function playUntilStopped(name, volume, loop) { return -1; }
}
