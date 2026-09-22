// hyprsnipe - sniper scope kill mode for Hyprland
// Left click: headshot (SIGKILL). Shift + left click: tranquilizer (SIGTERM).
// Mouse wheel: zoom. Right click or Esc: stand down.
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    id: root

    // Provided by the launcher: monitor snapshots and the cursor position
    readonly property string shotsDir: Quickshell.env("HYPRSNIPE_SHOTS") || ""
    readonly property point cursor: {
        const c = (Quickshell.env("HYPRSNIPE_CURSOR") || "").split(",");
        return c.length === 2 ? Qt.point(Number(c[0]), Number(c[1])) : Qt.point(-10000, -10000);
    }

    // "aim" while the scope is up, "feed" while the kill feed is shown
    property string phase: "aim"
    property string feedLabel: ""
    property string feedName: ""
    property color feedColor: "#ff3b30"
    property var feedScreen: null

    function report(label, name, color, screen) {
        root.feedLabel = label;
        root.feedName = name;
        root.feedColor = color;
        root.feedScreen = screen;
    }

    SoundEffect {
        id: gunshot
        source: Qt.resolvedUrl("sounds/shot.wav")
    }

    SoundEffect {
        id: dart
        source: Qt.resolvedUrl("sounds/dart.wav")
    }

    // Stand down automatically after 30 s without a shot
    Timer { interval: 30000; running: root.phase === "aim"; onTriggered: Qt.quit() }
    // Leave once the kill feed has been shown (also lets the shot sound finish)
    Timer { interval: 2500; running: root.phase === "feed"; onTriggered: Qt.quit() }

    // Window geometry is a snapshot: nothing can move while the scope holds the input
    Component.onCompleted: Hyprland.refreshToplevels()

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.phase === "aim"

            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "hyprsnipe"

            property real lensRadius: 140
            property real zoom: 2.0

            // Scope-up animation on open, masks the launch latency
            property real arm: 0.0
            NumberAnimation on arm {
                from: 0.0; to: 1.0; duration: 260; easing.type: Easing.OutBack; running: true
            }

            // Firing state: set on click, drives recoil + flash, then the kill lands
            property bool fired: false
            property bool pendingTranq: false
            property real fireProgress: 0.0
            NumberAnimation on fireProgress {
                running: win.fired
                from: 0.0; to: 1.0; duration: 220; easing.type: Easing.OutQuad
                onFinished: root.phase = "feed"
            }

            // Start under the cursor; on other monitors this lands off-screen
            property point aim: Qt.point(root.cursor.x - win.screen.x, root.cursor.y - win.screen.y)

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

            // Click fires the sound and the recoil; fireDelay lands the kill
            function shoot(tranquilizer) {
                if (win.fired) return;
                win.pendingTranq = tranquilizer;
                (tranquilizer ? dart : gunshot).play();
                win.fired = true;
                fireDelay.start();
            }

            Timer {
                id: fireDelay
                interval: 90
                onTriggered: {
                    const target = targetAt(win.aim);
                    if (target && target.pid > 1) {
                        Quickshell.execDetached(["kill", win.pendingTranq ? "-TERM" : "-KILL", String(target.pid)]);
                        const name = (target.class || "window").split(".").pop();
                        if (win.pendingTranq)
                            root.report("SEDATED", name, "#5ac8fa", win.screen);
                        else
                            root.report("HEADSHOT", name, "#ff3b30", win.screen);
                    } else {
                        root.report("MISSED", "", "#8e8e93", win.screen);
                    }
                }
            }

            // Everything shakes together on recoil
            Item {
                id: recoil
                anchors.fill: parent
                property real kick: 0.0
                transform: Translate { y: recoil.kick * 14 }
                NumberAnimation on kick {
                    running: win.fired
                    from: 0.0; to: 1.0; duration: 90; easing.type: Easing.OutQuad
                }

                // Snapshot of this monitor, taken by the launcher just before the scope opened
                Image {
                    id: snapshot
                    visible: false
                    smooth: true
                    source: root.shotsDir ? "file://" + root.shotsDir + "/" + win.screen.name + ".ppm" : ""
                }

                ShaderEffect {
                    anchors.fill: parent
                    property size resolution: Qt.size(width, height)
                    property point center: win.aim
                    property real radius: win.lensRadius + (1.0 - win.arm) * 40
                    property real darkness: 0.85 * win.arm
                    property real zoom: win.zoom
                    property real arm: win.arm
                    property real fire: win.fireProgress
                    property real hasShot: snapshot.status === Image.Ready ? 1.0 : 0.0
                    property var shot: snapshot
                    fragmentShader: Qt.resolvedUrl("shaders/scope.frag.qsb")
                }

                // Reticle: four red lines with a gap in the middle, and a center dot
                Item {
                    id: reticle
                    x: win.aim.x
                    y: win.aim.y
                    opacity: win.arm
                    readonly property color ink: "#ff3b30"
                    readonly property real gap: 10
                    Rectangle { x: -win.lensRadius; y: -0.5; width: win.lensRadius - reticle.gap; height: 1; color: reticle.ink }
                    Rectangle { x: reticle.gap; y: -0.5; width: win.lensRadius - reticle.gap; height: 1; color: reticle.ink }
                    Rectangle { x: -0.5; y: -win.lensRadius; width: 1; height: win.lensRadius - reticle.gap; color: reticle.ink }
                    Rectangle { x: -0.5; y: reticle.gap; width: 1; height: win.lensRadius - reticle.gap; color: reticle.ink }
                    Rectangle { x: -2; y: -2; width: 4; height: 4; radius: 2; color: reticle.ink }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.BlankCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPositionChanged: mouse => win.aim = Qt.point(mouse.x, mouse.y)
                onWheel: wheel => {
                    const step = wheel.angleDelta.y > 0 ? 1.15 : 1 / 1.15;
                    win.zoom = Math.max(1.5, Math.min(6.0, win.zoom * step));
                }
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

    // Kill feed: a click-through banner in the top-right corner, FPS style
    PanelWindow {
        id: feed
        visible: root.phase === "feed"
        screen: root.feedScreen ?? Quickshell.screens[0]

        color: "transparent"
        anchors { top: true; right: true }
        margins { top: 64; right: 24 }
        implicitWidth: feedBox.width + 60
        implicitHeight: feedBox.height
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "hyprsnipe-feed"
        mask: Region {}

        Rectangle {
            id: feedBox
            anchors.right: parent.right
            width: feedRow.implicitWidth + 28
            height: 38
            radius: 8
            color: "#e6141414"
            border.width: 1
            border.color: root.feedColor
            opacity: 0
            transform: Translate { id: slide; x: 60 }

            Row {
                id: feedRow
                anchors.centerIn: parent
                spacing: 10
                Text {
                    text: root.feedLabel
                    color: root.feedColor
                    font.bold: true
                    font.pixelSize: 15
                    font.letterSpacing: 1.5
                }
                Text {
                    visible: root.feedName !== ""
                    text: root.feedName
                    color: "white"
                    font.pixelSize: 15
                }
            }

            SequentialAnimation {
                running: feed.visible
                ParallelAnimation {
                    NumberAnimation { target: slide; property: "x"; from: 60; to: 0; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: feedBox; property: "opacity"; from: 0; to: 1; duration: 150 }
                }
                PauseAnimation { duration: 1800 }
                NumberAnimation { target: feedBox; property: "opacity"; to: 0; duration: 400 }
            }
        }
    }
}
