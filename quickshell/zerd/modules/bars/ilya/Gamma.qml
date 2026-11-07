pragma Singleton
import QtQuick
import qs.services as Svc

QtObject {
    signal settingsChanged()
    function isAnyEnabled() { return Svc.Hyprsunset.active; }
    function setEnabled(monitor, on) {
        if (on) Svc.Hyprsunset.enable(); else Svc.Hyprsunset.disable();
        settingsChanged();
    }
}
