// hyprsnipe - sniper scope kill mode for Hyprland
// Milestone 1: a scope overlay that follows the mouse. Esc or right click quits.
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    // Development safety net: always quit after 30 s, whatever happens
    Timer { interval: 30000; running: true; onTriggered: Qt.quit() }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "hyprsnipe"

            property real lensRadius: 140
            property point aim: Qt.point(-10000, -10000)

            ShaderEffect {
                anchors.fill: parent
                property size resolution: Qt.size(width, height)
                property point center: win.aim
                property real radius: win.lensRadius
                property real darkness: 0.85
                fragmentShader: Qt.resolvedUrl("shaders/scope.frag.qsb")
            }

            // Reticle: four red lines with a gap in the middle, and a center dot
            Item {
                id: reticle
                x: win.aim.x
                y: win.aim.y
                readonly property color ink: "#ff3b30"
                readonly property real gap: 10
                Rectangle { x: -win.lensRadius; y: -0.5; width: win.lensRadius - reticle.gap; height: 1; color: reticle.ink }
                Rectangle { x: reticle.gap; y: -0.5; width: win.lensRadius - reticle.gap; height: 1; color: reticle.ink }
                Rectangle { x: -0.5; y: -win.lensRadius; width: 1; height: win.lensRadius - reticle.gap; color: reticle.ink }
                Rectangle { x: -0.5; y: reticle.gap; width: 1; height: win.lensRadius - reticle.gap; color: reticle.ink }
                Rectangle { x: -2; y: -2; width: 4; height: 4; radius: 2; color: reticle.ink }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.BlankCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPositionChanged: mouse => win.aim = Qt.point(mouse.x, mouse.y)
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) Qt.quit();
                    // Milestone 2: find the window under win.aim and take the shot
                }
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Qt.quit()
            }
        }
    }
}
