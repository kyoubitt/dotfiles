import QtQuick
import qs.services
import qs.modules.common.widgets

// App icon and title of the focused window.
BarPill {
    id: root

    property int maxTextWidth: 260
    readonly property string title: NiriService.activeWindow?.title ?? ""
    readonly property string appId: NiriService.activeWindow?.app_id ?? ""
    visible: title.length > 0 && !vertical

    SmartAppIcon { icon: AppSearch.lookupDesktopEntry(root.appId)?.icon || AppSearch.guessIcon(root.appId); iconSize: 18 }
    BarText {
        text: root.title
        elide: Text.ElideRight
        width: 2 * Math.ceil(Math.min(implicitWidth, root.maxTextWidth) / 2)
    }
}
