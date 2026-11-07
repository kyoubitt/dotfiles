import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Services.UPower

AndroidQuickToggleButton {
    id: root

    toggleModel: QuickToggleModel {
        name: Translation.tr("Power Profile")
        toggled: PowerProfiles.profile !== PowerProfile.Balanced
        icon: PowerProfiles.profile === PowerProfile.PowerSaver ? "energy_savings_leaf" : PowerProfiles.profile === PowerProfile.Performance ? "local_fire_department" : "airwave"
        statusText: PowerProfiles.profile === PowerProfile.PowerSaver ? "Power Saver" : PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced"
        mainAction: () => {
            if (PowerProfiles.hasPerformanceProfile) {
                if (PowerProfiles.profile === PowerProfile.PowerSaver) PowerProfiles.profile = PowerProfile.Balanced
                else if (PowerProfiles.profile === PowerProfile.Balanced) PowerProfiles.profile = PowerProfile.Performance
                else PowerProfiles.profile = PowerProfile.PowerSaver
            } else {
                PowerProfiles.profile = PowerProfiles.profile === PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
            }
        }
        tooltipText: Translation.tr("Click to cycle through power profiles")
    }
}
