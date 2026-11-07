pragma Singleton
import QtQuick
import qs.services as Svc

QtObject {
    readonly property var win: Svc.NiriService.activeWindow
    readonly property string appClass: win?.app_id ?? "Desktop"
    readonly property string windowTitle: win?.title ?? ""
    readonly property string appTitle: win ? windowTitle : "Desktop"
    readonly property string displayText: appTitle !== "" ? appTitle : appClass
    readonly property bool isFocused: displayText !== ""
}
