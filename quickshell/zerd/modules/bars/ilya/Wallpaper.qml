pragma Singleton
import QtQuick
import qs.services as Svc

QtObject {
    property var engines: ({})
    function shuffle(screenName, transition) { Svc.Wallpapers.randomFromCurrentFolder(); }
}
