// hyprsnipe - sniper scope kill mode for Hyprland
// Left click: headshot (SIGKILL). Shift + left click: tranquilizer (SIGTERM).
// Right click or Esc: stand down.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    // Development safety net: always quit after 30 s, whatever happens
    Timer { interval: 30000; running: true; onTriggered: Qt.quit() }

    // Window geometry is a snapshot: nothing can move while the scope holds the input
    Component.onCompleted: Hyprland.refreshToplevels()

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

            // Returns the Hyprland client under point p (screen-local), or null
            function targetAt(p) {
                const mon = Hyprland.monitorFor(win.screen);
                const ws = mon ? mon.activeWorkspace : null;
                if (!ws || !ws.toplevels) return null;
                const gx = mon.x + p.x;
                const gy = mon.y + p.y;
                let best = null;
                let bestRank = Infinity;
                for (const t of ws.toplevels.values) {
                    const o = t.lastIpcObject;
                    if (!o || !o.at || !o.size || o.hidden || o.mapped === false) continue;
                    if (gx < o.at[0] || gy < o.at[1]
                            || gx >= o.at[0] + o.size[0] || gy >= o.at[1] + o.size[1]) continue;
                    // Stacking guess: fullscreen above floating above tiled,
                    // and among equals the most recently focused wins
                    const layer = o.fullscreen ? 0 : (o.floating ? 1 : 2);
                    const rank = layer * 1000 + (o.focusHistoryID ?? 999);
                    if (rank < bestRank) {
                        bestRank = rank;
                        best = o;
                    }
                }
                return best;
            }

            function shoot(tranquilizer) {
                const target = targetAt(win.aim);
                if (target && target.pid > 1) {
                    Quickshell.execDetached(["kill", tranquilizer ? "-TERM" : "-KILL", String(target.pid)]);
                    console.log("hyprsnipe:", tranquilizer ? "tranquilized" : "eliminated",
                                target.class, "pid", target.pid);
                } else {
                    console.log("hyprsnipe: missed");
                }
                Qt.quit();
            }

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
                    if (mouse.button === Qt.RightButton) {
                        Qt.quit();
                        return;
                    }
                    win.shoot((mouse.modifiers & Qt.ShiftModifier) !== 0);
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
