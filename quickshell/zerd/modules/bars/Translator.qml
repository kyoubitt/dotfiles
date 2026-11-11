import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * Translator widget with the `trans` commandline tool.
 */
Item {
    id: root

    // Sizes
    property real padding: 4

    // Widgets
    property var inputField: input

    // Widget variables
    property bool translationFor: false // Indicates if the translation is for an autocorrected text
    property string translatedText: ""
    property list<string> languages: []

    // Options
    property string targetLanguage: Config.options.language.translator.targetLanguage
    property string sourceLanguage: Config.options.language.translator.sourceLanguage
    property string hostLanguage: targetLanguage

    // States
    property bool showLanguageSelector: false
    property bool languageSelectorTarget: false // true for target language, false for source language

    function showLanguageSelectorDialog(isTargetLang: bool) {
        root.languageSelectorTarget = isTargetLang;
        root.showLanguageSelector = true
    }

    // Showing the tab puts the cursor in the input, so you can type straight away.
    onVisibleChanged: if (visible) Qt.callLater(() => root.inputField.forceActiveFocus())

    onFocusChanged: (focus) => {
        if (focus) {
            root.inputField.forceActiveFocus()
        }
    }

    Timer {
        id: translateTimer
        interval: Config.options?.sidebar?.translator?.delay ?? 300
        repeat: false
        onTriggered: () => {
            if (root.inputField.text.trim().length > 0) {
                // console.log("Translating with command:", translateProc.command);
                translateProc.running = false;
                translateProc.buffer = ""; // Clear the buffer
                translateProc.running = true; // Restart the process
            } else {
                root.translatedText = "";
            }
        }
    }

    Process {
        id: translateProc
        command: ["bash", "-c", `trans -brief -no-bidi`
            + ` -source '${StringUtils.shellSingleQuoteEscape(root.sourceLanguage)}'`
            + ` -target '${StringUtils.shellSingleQuoteEscape(root.targetLanguage)}'`
            + ` '${StringUtils.shellSingleQuoteEscape(root.inputField.text.trim())}'`]
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => {
                translateProc.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            // With -brief mode, we get output with no metadata
            root.translatedText = translateProc.buffer.trim();
        }
    }

    Process {
        id: getLanguagesProc
        command: ["trans", "-list-languages", "-no-bidi"]
        property list<string> bufferList: ["auto"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                getLanguagesProc.bufferList.push(data.trim());
            }
        }
        onExited: (exitCode, exitStatus) => {
            // Ensure "auto" is always the first language
            let langs = getLanguagesProc.bufferList
                .filter(lang => lang.trim().length > 0 && lang !== "auto")
                .sort((a, b) => a.localeCompare(b));
            langs.unshift("auto");
            root.languages = langs;
            getLanguagesProc.bufferList = []; // Clear the buffer
        }
    }

    // A language chip: tap to pick another.
    component LangChip: BarButton {
        id: chip
        property string label: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: BarStyle.radiusSmall
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 4
            BarText { Layout.fillWidth: true; text: chip.label; elide: Text.ElideRight; font.pixelSize: 13; color: BarStyle.text }
            BarIcon { name: "expand_more"; size: 18; color: BarStyle.subtext }
        }
    }

    // A small icon button for the card footers.
    component FootButton: BarButton {
        id: act
        property string glyph: ""
        tone: "plain"
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: 10
        opacity: enabled ? 1 : 0.35
        BarIcon { anchors.centerIn: parent; name: act.glyph; size: 18; color: BarStyle.subtext }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            LangChip {
                label: root.sourceLanguage === "auto" ? "Detect language" : root.sourceLanguage
                onTapped: root.showLanguageSelectorDialog(false)
            }
            BarButton {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                tone: "plain"
                enabled: root.sourceLanguage !== "auto"
                opacity: enabled ? 1 : 0.35
                BarIcon { anchors.centerIn: parent; name: "swap_horiz"; size: 20; color: BarStyle.text }
                onTapped: {
                    const s = root.sourceLanguage, t = root.targetLanguage
                    root.sourceLanguage = t; root.targetLanguage = s
                    Config.options.language.translator.sourceLanguage = t
                    Config.options.language.translator.targetLanguage = s
                    if (outputText.text.length > 0) root.inputField.text = root.translatedText
                    translateTimer.restart()
                }
            }
            LangChip {
                label: root.targetLanguage
                onTapped: root.showLanguageSelectorDialog(true)
            }
        }

        // what you type
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 100
            Layout.minimumHeight: 96
            radius: BarStyle.radiusMedium
            color: BarStyle.card
            border.width: 1
            border.color: input.activeFocus ? BarStyle.accent : BarStyle.edge
            Behavior on border.color { ColorAnimation { duration: BarStyle.motionFast } }
            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: input.forceActiveFocus() }
            Flickable {
                id: inFlick
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: inFoot.top; margins: 14; bottomMargin: 2 }
                contentWidth: width
                contentHeight: input.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextArea.flickable: TextArea {
                    id: input
                    width: inFlick.width
                    padding: 0
                    background: null
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    selectByMouse: true
                    color: BarStyle.text
                    selectionColor: BarStyle.accent
                    selectedTextColor: BarStyle.onAccent
                    font.family: Appearance.font.family.expressive
                    font.pixelSize: 14
                    renderType: Text.NativeRendering
                    onTextChanged: translateTimer.restart()
                    Keys.onEscapePressed: BarState.closeAll()
                }
            }
            BarText {
                visible: input.text.length === 0
                x: 14; y: 14
                text: "Type or paste text"
                font.pixelSize: 14
                color: BarStyle.subtext
                opacity: 0.8
            }
            RowLayout {
                id: inFoot
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 6; bottomMargin: 6 }
                spacing: 2
                BarText { Layout.fillWidth: true; text: input.text.length > 0 ? input.text.length + " characters" : ""; font.pixelSize: 11; color: BarStyle.subtext }
                FootButton { glyph: "content_paste"; onTapped: { input.text = Quickshell.clipboardText; input.forceActiveFocus() } }
                FootButton { glyph: "close"; enabled: input.text.length > 0; onTapped: { input.text = ""; input.forceActiveFocus() } }
            }
        }

        // what comes back
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 100
            Layout.minimumHeight: 96
            radius: BarStyle.radiusMedium
            color: Qt.tint(BarStyle.card, Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.10))
            border.width: 1
            border.color: BarStyle.edge
            Flickable {
                id: outFlick
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: outFoot.top; margins: 14; bottomMargin: 2 }
                contentWidth: width
                contentHeight: outputText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: outputText
                    width: outFlick.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: root.translatedText
                    color: BarStyle.text
                    selectionColor: BarStyle.accent
                    selectedTextColor: BarStyle.onAccent
                    font.family: Appearance.font.family.expressive
                    font.pixelSize: 14
                    renderType: Text.NativeRendering
                }
            }
            BarText {
                visible: outputText.text.length === 0
                x: 14; y: 14
                text: translateProc.running ? "Translating..." : "Translation"
                font.pixelSize: 14
                color: BarStyle.subtext
                opacity: 0.8
            }
            RowLayout {
                id: outFoot
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 6; bottomMargin: 6 }
                spacing: 2
                BarText { Layout.fillWidth: true; text: translateProc.running && outputText.text.length > 0 ? "Translating..." : ""; font.pixelSize: 11; color: BarStyle.subtext }
                FootButton { glyph: "content_copy"; enabled: outputText.text.trim().length > 0; onTapped: Quickshell.clipboardText = outputText.text }
                FootButton {
                    glyph: "travel_explore"
                    enabled: outputText.text.trim().length > 0
                    onTapped: {
                        let url = Config.options.search.engineBaseUrl + outputText.text
                        for (let site of Config.options.search.excludedSites) url += ` -site:${site}`
                        Qt.openUrlExternally(url)
                    }
                }
            }
        }
    }

    // The language picker: type to filter, arrows and Enter to choose, Esc or a click outside to close.
    Loader {
        anchors.fill: parent
        active: root.showLanguageSelector
        visible: root.showLanguageSelector
        z: 9999
        sourceComponent: Item {
            id: picker
            property string query: ""
            readonly property string current: root.languageSelectorTarget ? root.targetLanguage : root.sourceLanguage
            readonly property var shown: {
                const q = picker.query.trim().toLowerCase()
                return q === "" ? root.languages : root.languages.filter(l => l.toLowerCase().includes(q))
            }
            function pick(lang) {
                if (!lang) return
                if (root.languageSelectorTarget) {
                    root.targetLanguage = lang
                    Config.options.language.translator.targetLanguage = lang
                } else {
                    root.sourceLanguage = lang
                    Config.options.language.translator.sourceLanguage = lang
                }
                root.showLanguageSelector = false
                translateTimer.restart()
            }
            Component.onCompleted: search.forceActiveFocus()

            MouseArea { anchors.fill: parent; onClicked: root.showLanguageSelector = false }
            Rectangle {
                anchors.fill: parent
                radius: BarStyle.radiusMedium
                color: Qt.rgba(0, 0, 0, 0.35)
                MouseArea { anchors.fill: parent; onClicked: root.showLanguageSelector = false }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: BarStyle.radiusMedium
                color: BarStyle.surface
                border.width: 1
                border.color: BarStyle.edge
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        BarText { Layout.fillWidth: true; text: root.languageSelectorTarget ? "Translate to" : "Translate from"; font.pixelSize: 15; font.weight: Font.DemiBold }
                        BarButton {
                            Layout.preferredWidth: 30; Layout.preferredHeight: 30
                            tone: "plain"; radius: 10
                            BarIcon { anchors.centerIn: parent; name: "close"; size: 18; color: BarStyle.subtext }
                            onTapped: root.showLanguageSelector = false
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: BarStyle.radiusSmall
                        color: BarStyle.card
                        border.width: 1
                        border.color: search.activeFocus ? BarStyle.accent : BarStyle.edge
                        Behavior on border.color { ColorAnimation { duration: BarStyle.motionFast } }
                        BarIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 18; color: BarStyle.subtext }
                        TextInput {
                            id: search
                            x: 38; width: parent.width - 38 - 12; height: parent.height
                            verticalAlignment: TextInput.AlignVCenter
                            color: BarStyle.text; selectionColor: BarStyle.accent; selectedTextColor: BarStyle.onAccent
                            font.family: Appearance.font.family.expressive; font.pixelSize: 13
                            renderType: Text.NativeRendering
                            clip: true
                            onTextChanged: { picker.query = text; list.currentIndex = 0 }
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            Keys.onUpPressed: list.decrementCurrentIndex()
                            Keys.onReturnPressed: picker.pick(picker.shown[list.currentIndex])
                            Keys.onEnterPressed: picker.pick(picker.shown[list.currentIndex])
                            Keys.onEscapePressed: root.showLanguageSelector = false
                            BarText { visible: search.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "Type a language"; font.pixelSize: 13; color: BarStyle.subtext; opacity: 0.8 }
                        }
                    }
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: picker.shown
                        currentIndex: 0
                        highlightMoveDuration: 0
                        delegate: Rectangle {
                            required property int index
                            required property string modelData
                            readonly property bool isCurrent: modelData === picker.current
                            width: list.width
                            height: 38
                            radius: BarStyle.radiusSmall
                            color: isCurrent ? BarStyle.accentContainer : (ListView.isCurrentItem || rowMouse.containsMouse) ? BarStyle.hoverFill : "transparent"
                            BarText { anchors { left: parent.left; leftMargin: 12; right: tick.left; verticalCenter: parent.verticalCenter } text: modelData === "auto" ? "Detect language" : modelData; elide: Text.ElideRight; color: parent.isCurrent ? BarStyle.onAccentContainer : BarStyle.text }
                            BarIcon { id: tick; visible: parent.isCurrent; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } name: "check"; size: 18; color: BarStyle.onAccentContainer }
                            MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: picker.pick(modelData) }
                        }
                        BarText { visible: picker.shown.length === 0; anchors.centerIn: parent; text: "No match"; color: BarStyle.subtext }
                    }
                }
            }
        }
    }
}
