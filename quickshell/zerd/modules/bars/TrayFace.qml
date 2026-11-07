import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.iris.dock
import qs.services

// Status-notifier icons after ilyamiro's tray (serpantinum, AGPL-3.0). Left click brings the app's window forward (or
// starts / activates it when it has none), middle click is the secondary action, right click opens the app's own menu in
// the shell's menu, scrolling over a media player's icon changes its volume. An icon carries a badge for the app's
// waiting notifications. Passive, hidden or dock-duplicate icons sit behind the more button, which lists all of them.
BarPill {
    id: root
    strip: true

    property var window: null
    readonly property var all: SystemTray.items.values
    readonly property var hiddenIds: Config.options?.bars?.top?.trayHidden ?? []
    readonly property int maxIcons: Config.options?.bars?.top?.trayMax ?? 4
    // Apps already pinned in the dock are not repeated here.
    readonly property var items: all.filter(item => !hiddenIds.includes(item.id) && item.status !== Status.Passive && !root.inDock(item))
    readonly property var shownItems: items.slice(0, maxIcons)
    visible: all.length > 0
    tip: ""

    function inDock(item: var): bool {
        const keys = [item.id, item.title].map(s => String(s ?? "").toLowerCase()).filter(s => s.length > 0)
        const pinned = IrisDockOrder.pins.map(p => String(p).toLowerCase())
        const open = IrisDockOrder.entries.map(e => String(e.appId ?? "").toLowerCase())
        return !(Config.options?.bars?.top?.trayHidePinned ?? true) ? false
            : keys.some(k => pinned.concat(open).some(p => p.length > 2 && (k.includes(p) || p.includes(k))))
    }

    function norm(s: var): string { return String(s ?? "").toLowerCase().replace(/[^a-z0-9]/g, "") }
    function keysOf(item: var): var { return [item.id, item.title, item.tooltipTitle].map(s => root.norm(s)).filter(k => k.length >= 3) }
    function similar(a: string, k: string): bool { return a.length >= 3 && (a === k || k.includes(a) || a.includes(k)) }

    // the open window of this app, by app id (then by title for the known awkward apps)
    function windowFor(item: var): var {
        const keys = root.keysOf(item)
        const wins = NiriService.windows ?? []
        let hit = wins.find(w => keys.includes(root.norm(w.app_id)))
        if (!hit) hit = wins.find(w => keys.some(k => root.similar(root.norm(w.app_id), k)))
        const app = TrayService.getProblematicAppInfo(item)
        if (!hit && app) hit = wins.find(w => TrayService.matchesApp(w.app_id, app) || TrayService.matchesApp(w.title, app))
        return hit ?? null
    }
    function primary(item: var, cell: var): void {
        if (item.onlyMenu) { root.openMenu(item, cell); return }
        const w = root.windowFor(item)
        if (w) { NiriService.focusWindow(w.id); return }
        if (!TrayService.smartToggle(item)) item.activate()
    }
    function openMenu(item: var, cell: var): void {
        if (!item.hasMenu) return
        const p = cell.mapToItem(null, cell.width / 2, 0)
        BarState.sidebar = ""
        const cur = GlobalStates.barPopup
        GlobalStates.barPopup = (cur?.kind === "traymenu" && cur?.item === item.id) ? null : { kind: "traymenu", x: p.x, item: item.id }
    }
    function playerFor(item: var): var {
        const keys = root.keysOf(item)
        return (MprisController.players ?? []).find(p => keys.some(k => root.similar(root.norm(p.identity), k) || root.similar(root.norm(p.dbusName), k))) ?? null
    }
    // volume of a media player's icon, else the app's own scroll action
    function scrolled(item: var, event: var): bool {
        const p = root.playerFor(item)
        if (p && p.volumeSupported && p.canControl) {
            p.volume = Math.max(0, Math.min(1, p.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05)))
            return true
        }
        item.scroll(event.angleDelta.y, false)
        return false
    }
    // notifications waiting for this app
    function badgeFor(item: var): int {
        const groups = Notifications.groupsByAppName
        const keys = root.keysOf(item)
        let n = 0
        for (const name in groups)
            if (keys.some(k => root.similar(root.norm(name), k))) n += groups[name].notifications.length
        return n
    }
    function tipFor(item: var, volume: real): string {
        const base = TrayService.getTooltipForItem(item)
        return volume >= 0 ? base + "  " + Math.round(volume * 100) + "%" : base
    }

    Repeater {
        model: root.shownItems
        delegate: BarCell {
            id: entry
            required property var modelData
            readonly property int badge: root.badgeFor(modelData)
            readonly property bool attention: modelData.status === Status.NeedsAttention
            property real level: -1
            tip: root.tipFor(modelData, level)
            padding: 4
            wheelEnabled: true
            onTapped: root.primary(modelData, entry)
            onSecondary: root.openMenu(modelData, entry)
            onMiddle: modelData.secondaryActivate()
            onWheel: event => { if (root.scrolled(modelData, event)) { entry.level = root.playerFor(modelData)?.volume ?? -1; levelReset.restart() } }
            Timer { id: levelReset; interval: 1400; onTriggered: entry.level = -1 }

            Item {
                width: 20; height: 20
                BarArc { visible: entry.level >= 0; anchors.centerIn: parent; size: 26; lineWidth: 2; value: Math.max(0, entry.level) }
                IconImage {
                    id: glyph
                    anchors.centerIn: parent
                    width: 18; height: 18
                    source: TrayService.getSafeIcon(entry.modelData)
                    mipmap: true
                    opacity: entry.hovered ? 1 : 0.9
                    scale: entry.hovered ? 1.08 : 1
                    visible: status !== Image.Error && source.toString().length > 0
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
                BarIcon { anchors.centerIn: parent; name: "apps"; color: BarStyle.subtext; visible: !glyph.visible }
                // waiting notifications
                Rectangle {
                    visible: entry.badge > 0
                    x: parent.width - width * 0.6; y: -height * 0.4
                    width: Math.max(14, badgeText.implicitWidth + 6); height: 14; radius: 7
                    color: BarStyle.danger
                    border.width: 1.5; border.color: BarStyle.plate
                    BarText { id: badgeText; anchors.centerIn: parent; text: entry.badge > 9 ? "9+" : String(entry.badge); font.pixelSize: 9; font.weight: Font.Bold; color: Appearance.colors.colOnError }
                }
                // the app asks for attention
                Rectangle {
                    visible: entry.attention && entry.badge === 0
                    x: parent.width - 6; y: -2
                    width: 8; height: 8; radius: 4
                    color: BarStyle.accent
                    SequentialAnimation on opacity { running: entry.attention; loops: Animation.Infinite; NumberAnimation { to: 0.35; duration: 700 } NumberAnimation { to: 1; duration: 700 } }
                }
            }
        }
    }
    // More: everything in the tray, including hidden and passive icons.
    BarCell {
        visible: root.all.length > root.shownItems.length
        tip: "All tray icons"
        onTapped: root.openPopup("tray")
        BarIcon { name: "more_horiz"; color: BarStyle.subtext }
    }
}
