import QtQuick

// The tool buttons for an AnnotationLayer: history, then the drawing tools. The capture overlay adds a
// "select" tool in front (moving the box); the editor window adds crop.
Row {
    id: root

    required property var ann
    property bool withSelect: false
    property bool withCrop: false
    spacing: 4

    ShotButton { visible: root.withSelect; icon: "arrow_selector_tool"; tip: "Select and resize the area  (S)"; on: root.ann.tool === "select"; onTapped: root.ann.tool = "select" }
    ShotButton { icon: "undo"; tip: "Undo  (Ctrl+Z)"; enabledBtn: root.ann.canUndo; onTapped: root.ann.undo() }
    ShotButton { icon: "redo"; tip: "Redo  (Ctrl+Y)"; enabledBtn: root.ann.canRedo; onTapped: root.ann.redo() }
    ShotButton { icon: "delete"; tip: "Clear"; enabledBtn: root.ann.items.length > 0; onTapped: root.ann.clearAll() }
    Item { width: 9; height: 36; Rectangle { anchors.centerIn: parent; width: 1; height: 24; color: BarStyle.border } }
    ShotButton { icon: "brush"; tip: "Brush  (B)"; on: root.ann.tool === "brush"; onTapped: root.ann.tool = "brush" }
    ShotButton { icon: "horizontal_rule"; tip: "Line  (I)"; on: root.ann.tool === "line"; onTapped: root.ann.tool = "line" }
    ShotButton { icon: "north_east"; tip: "Arrow  (Z)"; on: root.ann.tool === "arrow"; onTapped: root.ann.tool = "arrow" }
    ShotButton { icon: "crop_square"; tip: "Rectangle  (R)"; on: root.ann.tool === "rect"; onTapped: root.ann.tool = "rect" }
    ShotButton { icon: "radio_button_unchecked"; tip: "Ellipse  (E)"; on: root.ann.tool === "ellipse"; onTapped: root.ann.tool = "ellipse" }
    ShotButton { icon: "title"; tip: "Text  (T)"; on: root.ann.tool === "text"; onTapped: root.ann.tool = "text" }
    ShotButton { icon: "looks_one"; tip: "Number  (M)"; on: root.ann.tool === "marker"; onTapped: root.ann.tool = "marker" }
    ShotButton { icon: "blur_on"; tip: "Blur  (U)"; on: root.ann.tool === "blur"; onTapped: root.ann.tool = "blur" }
    ShotButton { icon: "ink_highlighter"; tip: "Highlight  (G)"; on: root.ann.tool === "highlight"; onTapped: root.ann.tool = "highlight" }
    ShotButton { visible: root.withCrop; icon: "crop"; tip: "Crop  (C)"; on: root.ann.tool === "crop"; onTapped: root.ann.tool = "crop" }
}
