import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// The right panel, after end-4's SidebarRightContent: system buttons, quick sliders, the toggle grid,
// the notification list and the bottom group (calendar, to do, timer, ...).
Item {
    id: root
    property int sidebarPadding: 10
    property var screen: null
    property bool showAudioOutputDialog: false
    property bool showAudioInputDialog: false
    property bool showBluetoothDialog: false
    property bool showNightLightDialog: false
    property bool editMode: false

    Connections {
        target: BarState
        function onSidebarChanged(): void {
            if (BarState.sidebar !== "right") {
                root.showAudioOutputDialog = false
                root.showAudioInputDialog = false
                root.showBluetoothDialog = false
                root.showNightLightDialog = false
                root.editMode = false
            }
        }
    }

    // The network details are the shell's own popup (it knows iwd as well as NetworkManager).
    function openNetwork(): void {
        BarState.sidebar = ""
        GlobalStates.barPopup = { kind: "network", x: 1700 }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.sidebarPadding
        spacing: root.sidebarPadding

        SystemButtonRow {
            Layout.fillHeight: false
            Layout.fillWidth: true
            Layout.topMargin: 5
            Layout.bottomMargin: 0
            editMode: root.editMode
            onEditToggled: root.editMode = !root.editMode
        }

        Loader {
            id: slidersLoader
            Layout.fillWidth: true
            visible: active
            active: {
                const q = Config.options.sidebar.quickSliders
                if (!q.enable) return false
                return q.showMic || q.showVolume || q.showBrightness
            }
            sourceComponent: QuickSliders {
                screen: root.screen
            }
        }

        AndroidQuickPanel {
            Layout.fillWidth: true
            editMode: root.editMode
            onOpenAudioOutputDialog: root.showAudioOutputDialog = true
            onOpenAudioInputDialog: root.showAudioInputDialog = true
            onOpenBluetoothDialog: root.showBluetoothDialog = true
            onOpenNightLightDialog: root.showNightLightDialog = true
            onOpenWifiDialog: root.openNetwork()
        }

        CenterWidgetGroup {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        BottomWidgetGroup {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: false
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
        }
    }

    ToggleDialog {
        shown: root.showAudioOutputDialog
        onDismissed: root.showAudioOutputDialog = false
        sourceComponent: VolumeDialog { isSink: true }
    }

    ToggleDialog {
        shown: root.showAudioInputDialog
        onDismissed: root.showAudioInputDialog = false
        sourceComponent: VolumeDialog { isSink: false }
    }

    ToggleDialog {
        shown: root.showBluetoothDialog
        onDismissed: root.showBluetoothDialog = false
        onShownChanged: {
            const a = Bluetooth.defaultAdapter
            if (!a) return
            if (!shown) {
                a.discovering = false
            } else {
                a.enabled = true
                a.discovering = true
            }
        }
        sourceComponent: BluetoothDialog {}
    }

    ToggleDialog {
        shown: root.showNightLightDialog
        onDismissed: root.showNightLightDialog = false
        sourceComponent: NightLightDialog {}
    }
}
