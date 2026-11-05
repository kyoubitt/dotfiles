// Adapted from ilyamiro/serpantinum (AGPL-3.0): github.com/ilyamiro/serpantinum, src/quickshell/launcher
import QtQuick
import "./EmojiData.js" as EmojiData

QtObject {
    function search(query, limit) {
        return EmojiData.search(query, limit);
    }
}
