import QtQuick
import qs.services

BarPill {
    id: root
    BarText { text: DateTime.time; font.weight: Font.DemiBold }
    BarText { visible: !root.vertical; text: DateTime.shortDate; color: BarStyle.subtext }
}
