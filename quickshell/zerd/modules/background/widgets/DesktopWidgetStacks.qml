pragma Singleton

import QtQuick
import Quickshell

// Widget stacks (several cards sharing one slot) are not part of this shell.
Singleton {
    function show(output: string, stackId: string, key: string): void {}
    function step(output: string, stackId: string, dir: int): void {}
    function setHovered(stackId: string, hovered: bool): void {}
}
