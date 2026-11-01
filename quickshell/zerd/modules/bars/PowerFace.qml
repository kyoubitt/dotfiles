import QtQuick
import qs

// Opens the session screen (lock / log out / reboot / shut down).
BarPill {
    interactive: true
    tip: "Session"
    implicitWidth: thickness
    onClicked: GlobalStates.sessionOpen = true

    BarIcon { name: "power_settings_new"; color: BarStyle.text }
}
