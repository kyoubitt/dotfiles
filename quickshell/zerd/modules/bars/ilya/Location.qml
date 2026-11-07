pragma Singleton
import QtQuick
import qs.services as Svc

QtObject {
    readonly property string city: Svc.Weather.data.city ?? ""
}
