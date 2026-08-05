import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Wallpaper picker content: a plain scrolling grid of thumbnails/folders.
// Rewritten from scratch - the previous coverflow implementation had a
// persistent stray cursor-adjacent rendering artifact that survived every
// targeted fix (icon theme, cursor theme at every level, input masking,
// a fully opaque backdrop, and even fully suppressing the system cursor in
// favor of a hand-drawn one). None of that ruled it out conclusively enough
// to keep debugging indefinitely, so this trades the coverflow's fancy
// transform/effect stack for a plain GridView with standard MouseAreas -
// less code, fewer moving parts, nothing fancy left to misbehave.
Item {
    id: root
    property int columns: 5
    property real cellAspectRatio: 4 / 3
    property bool useDarkMode: Appearance.m3colors.darkmode

    readonly property string wallpapersRoot: `${FileUtils.trimFileProtocol(Directories.pictures)}/Wallpapers`
    readonly property bool inWallpapersRoot: Wallpapers.effectiveDirectory.indexOf(root.wallpapersRoot) === 0

    ListModel { id: wallpaperFlatModel }
    property var _pendingWallpapers: []
    readonly property var colorOrder: ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Monochrome"]

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
        Wallpapers.generateThumbnail("xx-large")
    }

    Connections {
        target: Wallpapers
        function onDirectoryChanged() {
            Wallpapers.generateThumbnail("xx-large")
        }
    }

    function handleFilePasting(event) {
        const currentClipboardEntry = Cliphist.entries[0]
        if (/^\d+\tfile:\/\/\S+/.test(currentClipboardEntry)) {
            const url = StringUtils.cleanCliphistEntry(currentClipboardEntry);
            Wallpapers.setDirectory(FileUtils.trimFileProtocol(decodeURIComponent(url)));
            event.accepted = true;
        } else {
            event.accepted = false;
        }
    }

    function selectWallpaperPath(filePath) {
        if (!filePath || filePath.length === 0) return
        const normalizedPath = FileUtils.trimFileProtocol(String(filePath))
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
            default:
                Wallpapers.applyFile(normalizedPath, root.useDarkMode);
                break;
        }
        GlobalStates.wallpaperSelectionTarget = "main";
        GlobalStates.wallpaperSelectorOpen = false;
    }

    function activate(index) {
        // wallpaperFlatModel is a plain ListModel (get(index) -> object);
        // Wallpapers.folderModel is a FolderListModel, which only exposes
        // per-role lookups (get(index, roleName) -> value).
        const isFlat = root.inWallpapersRoot
        const filePath = isFlat ? wallpaperFlatModel.get(index).filePath : grid.model.get(index, "filePath")
        const isDir = isFlat ? wallpaperFlatModel.get(index).fileIsDir : grid.model.get(index, "fileIsDir")
        if (!filePath) return
        if (isDir) {
            Wallpapers.setDirectory(filePath);
        } else {
            root.selectWallpaperPath(filePath);
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.wallpaperSelectorOpen = false;
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
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
            grid.currentIndex = Math.max(0, grid.currentIndex - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            grid.currentIndex = Math.min(grid.count - 1, grid.currentIndex + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            grid.currentIndex = Math.max(0, grid.currentIndex - root.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            grid.currentIndex = Math.min(grid.count - 1, grid.currentIndex + root.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activate(grid.currentIndex);
            event.accepted = true;
        }
    }

    implicitWidth: 1400
    implicitHeight: 780

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        MouseArea {
            // Absorbs clicks/back-forward-navigation on empty grid space
            // without stealing them from the cards above it - declared
            // before the grid so it sits behind everything in paint/input
            // order.
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.BackButton | Qt.ForwardButton
            onClicked: mouse => { mouse.accepted = false; }
            onPressed: event => {
                if (event.button === Qt.BackButton) {
                    Wallpapers.navigateBack();
                } else if (event.button === Qt.ForwardButton) {
                    Wallpapers.navigateForward();
                } else {
                    event.accepted = false;
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: root.inWallpapersRoot ? "Wallpapers" : Wallpapers.effectiveDirectory
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideMiddle
                }

                StyledText {
                    visible: Wallpapers.thumbnailGenerationRunning
                    text: "Generating thumbnails..."
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                cellWidth: width / root.columns
                cellHeight: cellWidth / root.cellAspectRatio
                currentIndex: -1
                model: root.inWallpapersRoot ? wallpaperFlatModel : Wallpapers.folderModel
                onModelChanged: currentIndex = -1
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: cellHeight * 4
                pixelAligned: true
                flickDeceleration: 3000
                maximumFlickVelocity: 3000
                ScrollBar.vertical: StyledScrollBar {}

                delegate: Item {
                    id: cell
                    required property int index
                    required property string filePath
                    required property string fileName
                    required property bool fileIsDir
                    required property url fileUrl

                    width: grid.cellWidth
                    height: grid.cellHeight

                    WallpaperDirectoryItem {
                        anchors.fill: parent
                        anchors.margins: 6
                        isCurrent: cell.index === grid.currentIndex
                        fileModelData: ({
                            filePath: cell.filePath,
                            fileName: cell.fileName,
                            fileIsDir: cell.fileIsDir,
                            fileUrl: cell.fileUrl
                        })
                        onActivated: {
                            grid.currentIndex = cell.index;
                            root.activate(cell.index);
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onWallpaperSelectorOpenChanged() {
            if (GlobalStates.wallpaperSelectorOpen) {
                root.forceActiveFocus();
            }
        }
    }
}
