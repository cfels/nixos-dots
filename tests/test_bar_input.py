import json
import shutil
import subprocess
import sys
import unittest

from support import REPO, IsolatedDesktop, install_preferences, install_qml_preferences
from test_lyrics_panel import block_after


@unittest.skipUnless(shutil.which("bun"), "Bun is required for bar gesture checks")
class BarInputTests(unittest.TestCase):
    def run_gesture(self, checks):
        source = (
            REPO / "Configs/config/.config/quickshell/moxi/bar/Bar.qml"
        ).read_text()
        mouse = source[source.index("id: pillMouse") :]
        bodies = {
            name: block_after(mouse, name + ":")
            for name in ("onPressed", "onReleased", "onPositionChanged", "onCanceled")
        }
        bodies["hold"] = block_after(source, "function openPanelFromHold(")
        shell = (REPO / "Configs/config/.config/quickshell/moxi/shell.qml").read_text()
        bodies["settings"] = (
            shell.split("onSettingsRequested:", 1)[1].splitlines()[0].strip()
        )
        script = (
            """import assert from "node:assert/strict";
const bodies = JSON.parse(await Bun.stdin.text());
let now = 1000;
globalThis.Date = {now() { return now; }};
globalThis.Qt = {LeftButton: 1, RightButton: 2};
globalThis.root = {settingsPage: null, showSettings(page) {this.settingsPage = page;}};
Object.assign(globalThis, {pressX: 0, pressY: 0, pressedAt: 0, swiping: false, activePress: false, pressHadOverlay: false, pressed: true});
globalThis.holdTimer = {interval: 420, active: false, restart() {this.active = true;}, stop() {this.active = false;}};
globalThis.bar = {
  held: false, holdHandled: false, panelOpen: false, hasPlayer: true, songSwipe: 0, openings: 0, settings: 0,
  panelRequested() {this.openings++; this.panelOpen = true;},
  settingsRequested() {this.settings++; new Function(bodies.settings)();},
  player: {canTogglePlaying: true, canGoNext: true, canGoPrevious: true, toggles: 0, skips: 0,
    togglePlaying() {this.toggles++;}, next() {this.skips++;}, previous() {this.skips--;}}
};
bar.openPanelFromHold = new Function(bodies.hold);
const press = new Function("mouse", bodies.onPressed);
const release = new Function("mouse", bodies.onReleased);
const move = new Function("mouse", bodies.onPositionChanged);
const cancel = new Function(bodies.onCanceled);
const left = {x: 20, y: 20, button: Qt.LeftButton, buttons: Qt.LeftButton};
"""
            + checks
        )
        result = subprocess.run(
            ["bun", "-e", script],
            input=json.dumps(bodies),
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_delayed_hold_callback_does_not_toggle_playback(self):
        self.run_gesture("""press(left); now += 600; release(left);
assert.equal(bar.openings, 1); assert.equal(bar.player.toggles, 0);""")

    def test_hold_callback_and_release_open_only_once(self):
        self.run_gesture("""press(left); now += 420; bar.openPanelFromHold(); now += 200; release(left);
assert.equal(bar.openings, 1); assert.equal(bar.player.toggles, 0);""")

    def test_short_click_still_controls_playback(self):
        self.run_gesture("""press(left); now += 80; release(left);
assert.equal(bar.openings, 0); assert.equal(bar.player.toggles, 1);""")

    def test_right_click_opens_appearance_without_toggling_music(self):
        self.run_gesture("""const right = {...left, button: Qt.RightButton, buttons: Qt.RightButton};
press(right); release(right);
assert.equal(bar.settings, 1);
if (root.settingsPage !== "appearance") throw new Error("Right-click opened " + root.settingsPage);
assert.equal(bar.player.toggles, 0);""")

    def test_overlay_closing_during_press_does_not_start_music(self):
        self.run_gesture("""bar.panelOpen = true; press(left); bar.panelOpen = false; now += 80; release(left);
assert.equal(bar.player.toggles, 0);""")

    def test_cancelled_press_does_not_toggle_playback(self):
        self.run_gesture("""press(left); cancel(); now += 100; release(left);
assert.equal(bar.openings, 0); assert.equal(bar.player.toggles, 0);""")

    def test_long_horizontal_swipe_skips_without_starting_playback(self):
        self.run_gesture("""press(left); move({...left, x: -40}); now += 700; release(left);
assert.equal(bar.openings, 0); assert.equal(bar.player.toggles, 0); assert.equal(bar.player.skips, 1);""")

    def test_panel_open_blocks_song_swipes_in_both_directions(self):
        self.run_gesture("""bar.panelOpen = true;
for (const x of [-40, 80]) {
  press(left); move({...left, x}); release(left);
  assert.equal(swiping, false); assert.equal(bar.songSwipe, 0);
}
assert.equal(bar.player.skips, 0); assert.equal(bar.player.toggles, 0);""")

    def test_panel_opened_during_swipe_cancels_track_change(self):
        self.run_gesture("""press(left); move({...left, x: -40});
bar.panelOpen = true; release(left);
assert.equal(bar.player.skips, 0); assert.equal(bar.songSwipe, 0); assert.equal(swiping, false);""")

    def test_hold_then_swipe_does_not_skip_a_song(self):
        self.run_gesture("""press(left); now += 420; bar.openPanelFromHold();
move({...left, x: 80}); release(left);
assert.equal(bar.openings, 1); assert.equal(bar.player.skips, 0); assert.equal(bar.player.toggles, 0);""")

    def test_overlay_closed_during_swipe_still_blocks_track_change(self):
        self.run_gesture("""bar.panelOpen = true; press(left); bar.panelOpen = false;
move({...left, x: -40}); release(left);
assert.equal(bar.player.skips, 0); assert.equal(bar.player.toggles, 0);""")


class BarVisualizerTests(unittest.TestCase):
    def test_toggle_hides_dots_reclaims_space_and_stops_cava(self):
        desktop = IsolatedDesktop()
        self.addCleanup(desktop.close)
        source = REPO / "Configs/config/.config/quickshell/moxi"
        shutil.copytree(source / "bar", desktop.work / "bar")
        install_qml_preferences(desktop.work)
        install_preferences(desktop.home / ".config/hypr/scripts")
        visualizer = desktop.work / "bar/AudioVisualizer.qml"
        visualizer.write_text(
            visualizer.read_text()
            .replace(
                "id: visualizer\n", "id: visualizer\n\tproperty int testExits: 0\n", 1
            )
            .replace(
                "id: cava\n", "id: cava\n\t\tonExited: visualizer.testExits++\n", 1
            )
        )
        cava = desktop.work / "bin/cava"
        cava.write_text(
            f"#!{sys.executable}\nimport signal\n"
            'print(";".join(["700"] * 15) + ";", flush=True)\nsignal.pause()\n'
        )
        cava.chmod(0o755)
        scenario = (REPO / "tests/qml/BarVisualizerScenario.qml").read_text()
        declaration = block_after(
            (source / "bar/Bar.qml").read_text(), "AudioVisualizer {"
        )
        (desktop.work / "shell.qml").write_text(
            scenario.replace("// BAR_VISUALIZER", declaration)
        )
        (desktop.work / "run.sh").write_text(
            "mkdir -p /tmp/runtime\nchmod 700 /tmp/runtime\nexec qs -p /work/shell.qml --no-color\n"
        )
        result = desktop.run(
            "/work/run.sh",
            QT_QPA_PLATFORM="offscreen",
            QT_QUICK_BACKEND="software",
            QML_IMPORT_PATH="/run/current-system/sw/lib/qt-6/qml",
            XDG_RUNTIME_DIR="/tmp/runtime",
            DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/no-bus",
            PULSE_SERVER="unix:/tmp/no-pulse",
            LANG="C.UTF-8",
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("BAR_VISUALIZER_OK", output)
        for error in (
            "BAR_VISUALIZER_FAILED",
            "TypeError",
            "ReferenceError",
            "Binding loop",
        ):
            self.assertNotIn(error, output)
