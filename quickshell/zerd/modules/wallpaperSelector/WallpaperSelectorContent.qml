import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io

MouseArea {
    id: root
    property int columns: 4
    property real previewCellAspectRatio: 4 / 3
    property bool useDarkMode: Appearance.m3colors.darkmode
    property string _lastThumbnailSizeName: ""

    // When browsing inside the Wallpapers folder, skip the per-theme
    // subfolder click-through and show every image flattened, labeled
    // "<Theme> - <name>" so the theme name still shows at the bottom.
    readonly property string wallpapersRoot: `${FileUtils.trimFileProtocol(Directories.pictures)}/Wallpapers`
    readonly property bool inWallpapersRoot: Wallpapers.effectiveDirectory.indexOf(root.wallpapersRoot) === 0

    ListModel { id: wallpaperFlatModel }
    property var _pendingWallpapers: []
    readonly property var colorOrder: ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Monochrome"]

    // Single pass: tag_wallpaper_colors.py already walks the directory itself
    // (and caches its per-file classification by mtime), so scanning with a
    // separate `find` first and waiting for it to fully exit before even
    // starting classification was a redundant extra process + serial wait.
    Process {
        id: wallpaperColorTagProc
        command: [FileUtils.trimFileProtocol(Directories.scriptPath) + "/colors/tag_wallpaper_colors.py", root.wallpapersRoot]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line || line.length === 0) return
                const idx = line.lastIndexOf("\t")
                if (idx < 0) return
                const path = line.slice(0, idx)
                const color = line.slice(idx + 1)
                const rel = path.startsWith(root.wallpapersRoot + "/") ? path.slice(root.wallpapersRoot.length + 1) : path
                const parts = rel.split("/")
                const base = parts[parts.length - 1]
                const theme = parts.slice(0, -1).join("/")
                const name = base.replace(/\.[^.]+$/, "")
                root._pendingWallpapers.push({
                    filePath: path,
                    fileName: theme.length > 0 ? `${theme} - ${name}` : name,
                    fileIsDir: false,
                    fileUrl: Qt.resolvedUrl(path),
                    color: color
                })
            }
        }
        onExited: (exitCode, exitStatus) => {
            const sorted = root._pendingWallpapers.slice().sort((a, b) => {
                const ca = root.colorOrder.indexOf(a.color ?? "Monochrome")
                const cb = root.colorOrder.indexOf(b.color ?? "Monochrome")
                if (ca !== cb) return ca - cb
                return a.fileName.localeCompare(b.fileName)
            })
            wallpaperFlatModel.clear()
            for (const item of sorted) wallpaperFlatModel.append(item)
        }
    }

    function rescanWallpapersFlat() {
        wallpaperFlatModel.clear()
        root._pendingWallpapers = []
        wallpaperColorTagProc.running = false
        wallpaperColorTagProc.running = true
    }

    onInWallpapersRootChanged: {
        if (root.inWallpapersRoot) root.rescanWallpapersFlat()
    }

    Component.onCompleted: {
        if (root.inWallpapersRoot) root.rescanWallpapersFlat()
    }

    function updateThumbnails() {
        // Always generate at the largest bucket - the coverflow cards render
        // well above the "large" (256px) bucket, and dynamically picking a
        // smaller bucket left most of the library stuck with stale, blurry
        // upscaled thumbnails once cached (freedesktop caching keys off
        // mtime, not the size actually needed).
        const thumbnailSizeName = "xx-large"
        root._lastThumbnailSizeName = thumbnailSizeName
        Wallpapers.generateThumbnail(thumbnailSizeName)
    }

    Connections {
        target: Wallpapers
        function onDirectoryChanged() {
            root.updateThumbnails()
        }
    }

    Connections {
        target: Wallpapers.folderModel
        function onCountChanged() {
            if (!GlobalStates.wallpaperSelectorOpen) return;
            if (!root._lastThumbnailSizeName || root._lastThumbnailSizeName.length === 0) return;
            Wallpapers.generateThumbnail(root._lastThumbnailSizeName)
        }
    }

    function handleFilePasting(event) {
        const currentClipboardEntry = Cliphist.entries[0]
        if (/^\d+\tfile:\/\/\S+/.test(currentClipboardEntry)) {
            const url = StringUtils.cleanCliphistEntry(currentClipboardEntry);
            Wallpapers.setDirectory(FileUtils.trimFileProtocol(decodeURIComponent(url)));
            event.accepted = true;
        } else {
            event.accepted = false; // No image, let text pasting proceed
        }
    }

    function selectWallpaperPath(filePath) {
        if (filePath && filePath.length > 0) {
            const normalizedPath = FileUtils.trimFileProtocol(String(filePath))
            // Check Config first (set by the settings window via IPC), then GlobalStates
            const configTarget = Config.options?.wallpaperSelector?.selectionTarget;
            let target = (configTarget && configTarget !== "main") ? configTarget : GlobalStates.wallpaperSelectionTarget;
            
            switch (target) {
                case "backdrop":
                    Config.setNestedValue("background.backdrop.useMainWallpaper", false);
                    Config.setNestedValue("background.backdrop.wallpaperPath", normalizedPath);
                    break;
                case "waffle":
                    Config.setNestedValue("waffles.background.useMainWallpaper", false);
                    Config.setNestedValue("waffles.background.wallpaperPath", normalizedPath);
                    break;
                case "waffle-backdrop":
                    Config.setNestedValue("waffles.background.backdrop.useMainWallpaper", false);
                    Config.setNestedValue("waffles.background.backdrop.wallpaperPath", normalizedPath);
                    break;
                default: // "main"
                    // Callers of selectWallpaperPath already branched on
                    // fileIsDir before reaching here, so this is always a
                    // file - applyFile() skips the redundant "is it a
                    // directory?" subprocess round-trip that select() does.
                    Wallpapers.applyFile(normalizedPath, root.useDarkMode);
                    break;
            }
            // Reset GlobalStates only (Config resets on its own via defaults)
            GlobalStates.wallpaperSelectionTarget = "main";
            GlobalStates.wallpaperSelectorOpen = false;
        }
    }

    acceptedButtons: Qt.LeftButton | Qt.BackButton | Qt.ForwardButton

    onClicked: mouse => {
        mouse.accepted = false;
    }

    onPressed: event => {
        if (event.button === Qt.BackButton) {
            Wallpapers.navigateBack();
        } else if (event.button === Qt.ForwardButton) {
            Wallpapers.navigateForward();
        } else {
            event.accepted = false;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.wallpaperSelectorOpen = false;
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) { // Intercept Ctrl+V to handle "paste to go to" in pickers
            root.handleFilePasting(event);
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Up) {
            Wallpapers.navigateUp();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Left) {
            Wallpapers.navigateBack();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Right) {
            Wallpapers.navigateForward();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            grid.moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            grid.moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            grid.moveSelection(-grid.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            grid.moveSelection(grid.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            grid.activateCurrent();
            event.accepted = true;
        }
    }

    implicitHeight: mainLayout.implicitHeight
    implicitWidth: mainLayout.implicitWidth

    GlassBackground {
        id: wallpaperGridBackground
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        focus: true
        Keys.forwardTo: [root]
        border.width: 0
        fallbackColor: "transparent"
        inirColor: "transparent"
        auroraTransparency: 1
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingLarge
            : (Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1)

        property int calculatedRows: Math.ceil(grid.count / grid.columns)

        implicitWidth: gridColumnLayout.implicitWidth
        implicitHeight: gridColumnLayout.implicitHeight

        RowLayout {
            id: mainLayout
            anchors.fill: parent
            spacing: -4

            ColumnLayout {
                id: gridColumnLayout
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    id: gridDisplayRegion
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1500
                    Layout.preferredHeight: 500

                    StyledIndeterminateProgressBar {
                        id: indeterminateProgressBar
                        visible: Wallpapers.thumbnailGenerationRunning && value == 0
                        anchors {
                            bottom: parent.top
                            left: parent.left
                            right: parent.right
                            leftMargin: 4
                            rightMargin: 4
                        }
                    }

                    StyledProgressBar {
                        visible: Wallpapers.thumbnailGenerationRunning && value > 0
                        value: Wallpapers.thumbnailGenerationProgress
                        anchors.fill: indeterminateProgressBar
                    }

                    ListView {
                        id: grid
                        visible: Wallpapers.folderModel.count > 0

                        orientation: ListView.Horizontal
                        readonly property int columns: 1
                        property real cellHeight: height * 0.72
                        property real cellWidth: cellHeight * root.previewCellAspectRatio

                        anchors.fill: parent
                        transform: Translate { id: gridSlide; x: 0 }
                        spacing: -90
                        preferredHighlightBegin: (width - cellWidth) / 2
                        preferredHighlightEnd: (width - cellWidth) / 2
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        snapMode: ListView.SnapOneItem
                        highlightMoveDuration: 380
                        interactive: false
                        clip: true

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                                    grid.moveSelection(-1)
                                } else if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                                    grid.moveSelection(1)
                                }
                            }
                        }
                        keyNavigationWraps: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.horizontal: StyledScrollBar {}

                        Component.onCompleted: {
                            root.updateThumbnails()
                        }

                        function moveSelection(delta) {
                            const count = grid.model.count;
                            if (count === 0) return;
                            const raw = currentIndex + delta;
                            const wrapped = ((raw % count) + count) % count;
                            const isWrap = raw < 0 || raw >= count;
                            if (isWrap) {
                                if (wrapFlowAnim.running) return;
                                wrapFlowAnim.dir = delta > 0 ? 1 : -1;
                                wrapFlowAnim.targetIndex = wrapped;
                                wrapFlowAnim.start();
                            } else {
                                currentIndex = wrapped;
                                positionViewAtIndex(currentIndex, ListView.Center);
                            }
                        }

                        // Continuing past the last/first item normally teleports back to the
                        // other end (highlightMoveDuration briefly forced to 0). Instead, slide
                        // the strip onward in the same direction and cross-fade into the wrapped
                        // position, so it reads as an unbroken loop rather than a jump cut.
                        SequentialAnimation {
                            id: wrapFlowAnim
                            property int targetIndex: 0
                            property int dir: 1 // +1 wrapping last -> first, -1 wrapping first -> last

                            ParallelAnimation {
                                NumberAnimation { target: grid; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InQuad }
                                NumberAnimation { target: gridSlide; property: "x"; to: -wrapFlowAnim.dir * 60; duration: 140; easing.type: Easing.InQuad }
                            }
                            ScriptAction {
                                script: {
                                    grid.highlightMoveDuration = 0;
                                    grid.currentIndex = wrapFlowAnim.targetIndex;
                                    grid.positionViewAtIndex(wrapFlowAnim.targetIndex, ListView.Center);
                                    grid.highlightMoveDuration = 380;
                                    gridSlide.x = wrapFlowAnim.dir * 60;
                                }
                            }
                            ParallelAnimation {
                                NumberAnimation { target: grid; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutQuad }
                                NumberAnimation { target: gridSlide; property: "x"; to: 0; duration: 180; easing.type: Easing.OutQuad }
                            }
                        }

                        function activateCurrent() {
                            console.log("[wallpaperDebug] activateCurrent called, currentIndex =", currentIndex, "count =", grid.model.count)
                            const isFlat = root.inWallpapersRoot
                            const filePath = isFlat ? wallpaperFlatModel.get(currentIndex).filePath : grid.model.get(currentIndex, "filePath")
                            const isDir = isFlat ? wallpaperFlatModel.get(currentIndex).fileIsDir : grid.model.get(currentIndex, "fileIsDir")
                            if (isDir) {
                                Wallpapers.setDirectory(filePath);
                            } else {
                                root.selectWallpaperPath(filePath);
                            }
                        }

                        model: root.inWallpapersRoot ? wallpaperFlatModel : Wallpapers.folderModel
                        onModelChanged: currentIndex = 0
                        delegate: WallpaperDirectoryItem {
                            id: coverItem
                            required property int index
                            required property string filePath
                            required property string fileName
                            required property bool fileIsDir
                            required property url fileUrl

                            fileModelData: ({
                                filePath: filePath,
                                fileName: fileName,
                                fileIsDir: fileIsDir,
                                fileUrl: fileUrl
                            })
                            width: grid.cellWidth
                            height: grid.cellHeight

                            // Distance is derived from the item's actual on-screen position (relative
                            // to the view's animated contentX) rather than the discrete currentIndex.
                            // Using currentIndex directly made the scale/opacity pop instantly to the
                            // destination item while the view was still animating there, so during
                            // fast scrolling the "big" card and the visually-centered card would be
                            // out of sync - looked like the order was messed up.
                            readonly property real stride: grid.cellWidth + grid.spacing
                            readonly property real distanceFromCenter: stride > 0
                                ? ((x + width / 2) - (grid.contentX + grid.width / 2)) / stride
                                : 0
                            coverScale: Math.max(0.55, 1 - Math.abs(distanceFromCenter) * 0.22)
                            coverOpacity: 1
                            suppressGlow: grid.moving
                            z: 100 - Math.abs(distanceFromCenter)

                            colBackground: "transparent"
                            colText: "transparent"

                            onActivated: {
                                if (fileIsDir) {
                                    Wallpapers.setDirectory(filePath);
                                } else {
                                    root.selectWallpaperPath(filePath);
                                }
                            }
                        }

                        layer.enabled: true
                        layer.effect: GE.OpacityMask {
                            maskSource: Rectangle {
                                width: gridDisplayRegion.width
                                height: gridDisplayRegion.height
                                radius: wallpaperGridBackground.radius
                            }
                        }
                    }

                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onWallpaperSelectorOpenChanged() {
            if (GlobalStates.wallpaperSelectorOpen && monitorIsFocused) {
                wallpaperGridBackground.forceActiveFocus();
            }
        }
    }

}
