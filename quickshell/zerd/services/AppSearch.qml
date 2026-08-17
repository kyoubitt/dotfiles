pragma Singleton

import QtQuick
import qs.modules.common
import qs.modules.common.functions
import Quickshell

/**
 * - Eases fuzzy searching for applications by name
 * - Guesses icon name for window class name
 */
Singleton {
    id: root
    property bool sloppySearch: Config.options?.search.sloppy ?? false
    property real scoreThreshold: 0.2
    property var substitutions: ({
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "code": "visual-studio-code",
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "footclient": "foot",
        "spotify": "spotify",
        "brave-browser": "brave-desktop",
        // These specific icons live behind the icon theme's Dark->Light
        // symlink (apps/scalable is a symlink to the Light variant), which
        // the named icon-theme lookup fails to resolve for some icons even
        // though the files genuinely exist - pointing directly at the file
        // sidesteps that lookup entirely.
        "claude": "/usr/share/icons/Colloid-Purple-Light/apps/scalable/claude.svg",
        "claude-desktop": "/usr/share/icons/Colloid-Purple-Light/apps/scalable/claude.svg",
        "btop": "/usr/share/icons/Colloid-Purple-Light/apps/scalable/btop.svg",
        "CMakeSetup": "/usr/share/icons/Colloid-Purple-Light/apps/scalable/cmake.svg",
        // Thunar's actual icon isn't in Colloid at all (dark or light) -
        // only hicolor has it - so it was falling through to a generic
        // mimetype folder glyph instead of Thunar's real branded icon.
        "org.xfce.thunar": "/usr/share/icons/hicolor/scalable/apps/org.xfce.thunar.svg",
        "thunar": "/usr/share/icons/hicolor/scalable/apps/org.xfce.thunar.svg",
    })
    property var regexSubstitutions: [
        {
            "regex": /^steam_app_(\d+)$/,
            "replace": "steam_icon_$1"
        },
        {
            "regex": /Minecraft.*/,
            // Was the generic Colloid grass-block glyph - swapped for
            // PrismLauncher's own real icon (the launcher actually in use).
            // Points at the same icon name the pinned PrismLauncher entry
            // already resolves to (full color) rather than YAMIS's
            // monochrome rendition - that one was meant to pick up the
            // dock's accent-color wash, but that wash was removed globally
            // from DockAppIcon, leaving it rendering as a flat pale-white
            // blob instead of PrismLauncher's real colors.
            "replace": "org.prismlauncher.PrismLauncher"
        },
        {
            "regex": /.*polkit.*/,
            "replace": "system-lock-screen"
        },
        {
            "regex": /gcr.prompter/,
            "replace": "system-lock-screen"
        }
    ]

    // Cached - rebuilt with debounce to avoid UI freeze on DesktopEntries updates
    property var _cachedList: []
    property var _cachedPreppedNames: []
    property var _cachedPreppedIcons: []

    readonly property var list: _cachedList
    readonly property var preppedNames: _cachedPreppedNames
    readonly property var preppedIcons: _cachedPreppedIcons

    QtObject {
        id: internal
        property var rebuildTimer: Timer {
            interval: 500
            onTriggered: root._rebuildCache()
        }
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { internal.rebuildTimer.restart() }
    }

    Component.onCompleted: _rebuildCache()

    function _rebuildCache(): void {
        const entries = Array.from(DesktopEntries.applications.values)
            .sort((a, b) => a.name.localeCompare(b.name))
        _cachedList = entries
        _cachedPreppedNames = entries.map(a => ({ name: Fuzzy.prepare(`${a.name} `), entry: a }))
        _cachedPreppedIcons = entries.map(a => ({ name: Fuzzy.prepare(`${a.icon} `), entry: a }))
    }

    function fuzzyQuery(search: string): var {
        if (_cachedList.length === 0) return []
        if (root.sloppySearch) {
            const results = _cachedList.map(obj => ({
                entry: obj,
                score: Levendist.computeScore(obj.name.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => b.score - a.score)
            return results
                .map(item => item.entry)
        }

        return Fuzzy.go(search, preppedNames, {
            all: true,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
    }

    function iconExists(iconName) {
        if (!iconName || iconName.length == 0) return false;
        return (Quickshell.iconPath(iconName, true).length > 0) 
            && !iconName.includes("image-missing");
    }

    function getReverseDomainNameAppName(str) {
        return str.split('.').slice(-1)[0]
    }

    function getKebabNormalizedAppName(str) {
        return str.toLowerCase().replace(/\s+/g, "-");
    }

    function getUndescoreToKebabAppName(str) {
        return str.toLowerCase().replace(/_/g, "-");
    }

    function guessIcon(str) {
        if (!str || str.length == 0) return "image-missing";

        // Quickshell's desktop entry lookup
        const entry = DesktopEntries.heuristicLookup(str);
        if (entry) return entry.icon;

        // Normal substitutions
        if (substitutions[str]) return substitutions[str];
        if (substitutions[str.toLowerCase()]) return substitutions[str.toLowerCase()];

        // Regex substitutions
        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            if (!substitution.regex.test(str)) continue;

            // Multiple candidates - use the first one that actually exists in
            // the current icon theme, instead of committing blind to the first
            if (substitution.candidates) {
                const found = substitution.candidates.find(c => iconExists(c));
                if (found) return found;
                continue;
            }

            const replacedName = str.replace(substitution.regex, substitution.replace);
            if (replacedName != str) return replacedName;
        }

        // Icon exists -> return as is
        if (iconExists(str)) return str;


        // Simple guesses
        const lowercased = str.toLowerCase();
        if (iconExists(lowercased)) return lowercased;

        const reverseDomainNameAppName = getReverseDomainNameAppName(str);
        if (iconExists(reverseDomainNameAppName)) return reverseDomainNameAppName;

        const lowercasedDomainNameAppName = reverseDomainNameAppName.toLowerCase();
        if (iconExists(lowercasedDomainNameAppName)) return lowercasedDomainNameAppName;

        const kebabNormalizedGuess = getKebabNormalizedAppName(str);
        if (iconExists(kebabNormalizedGuess)) return kebabNormalizedGuess;

        const undescoreToKebabGuess = getUndescoreToKebabAppName(str);
        if (iconExists(undescoreToKebabGuess)) return undescoreToKebabGuess;

        // Search in desktop entries
        if (_cachedPreppedIcons.length > 0) {
            const iconSearchResults = Fuzzy.go(str, preppedIcons, {
                all: true,
                key: "name"
            }).map(r => r.obj.entry);
            if (iconSearchResults.length > 0) {
                const guess = iconSearchResults[0].icon
                if (iconExists(guess)) return guess;
            }
        }

        const nameSearchResults = root.fuzzyQuery(str);
        if (nameSearchResults.length > 0) {
            const guess = nameSearchResults[0].icon
            if (iconExists(guess)) return guess;
        }


        // Give up
        return str;
    }

    // Returns a ready-to-use icon source (handles both icon names and absolute paths)
    function getIconSource(str, fallback): string {
        fallback = fallback ?? "image-missing"
        const icon = guessIcon(str);
        // Absolute path - return as file:// URL
        if (icon.startsWith("/")) {
            return "file://" + icon;
        }
        // Icon name - resolve via theme
        return Quickshell.iconPath(icon, fallback);
    }

    // Resolves an icon name/path directly (for when you already have the icon from a DesktopEntry)
    function resolveIcon(iconNameOrPath, fallback): string {
        fallback = fallback ?? "image-missing"
        if (!iconNameOrPath) return Quickshell.iconPath(fallback, "");
        // Absolute path - return as file:// URL
        if (iconNameOrPath.startsWith("/")) {
            return "file://" + iconNameOrPath;
        }
        // Icon name - resolve via theme
        return Quickshell.iconPath(iconNameOrPath, fallback);
    }
}
