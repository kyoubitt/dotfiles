pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

QtObject {
    readonly property string username: Quickshell.env("USER") ?? "user"
    readonly property string desktopEnv: "niri"
    readonly property string avatarPath: ""
    readonly property string osName: "Arch Linux"
    readonly property bool hasBatSupply: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
    readonly property bool isDesktop: !hasBatSupply
}
