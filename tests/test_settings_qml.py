import json
import os
import shutil
import subprocess
import unittest
from pathlib import Path

from support import REPO, IsolatedDesktop, install_preferences


class SettingsQmlTests(unittest.TestCase):
    def test_command_opens_panel_through_ipc(self):
        desktop = IsolatedDesktop()
        self.addCleanup(desktop.close)
        target = desktop.home / ".config/quickshell/moxi"
        shutil.copytree(REPO / "Configs/config/.config/quickshell/moxi", target)
        install_preferences(desktop.home / ".config/hypr/scripts")
        source = (REPO / "Configs/config/.config/quickshell/moxi/shell.qml").read_text()
        controller = source[
            source.index("\tfunction showSettings(") : source.index("\tIslandWindow {")
        ]
        (target / "shell.qml").write_text(
            """import Quickshell
import Quickshell.Io
import QtQuick
ShellRoot {
    id: root
    property bool panelExpanded: false
    QtObject { id: closeTimer; function stop() {} }
    QtObject { id: openGrace; function restart() {} }
    QtObject { id: pill; property real pillWidth: 210; property real pillHeight: 38; property real pillTop: 4 }
    QtObject {
        id: panel
        function setAnchor(width, height, top) {}
        function showSettings(page) { console.info("SETTINGS_PANEL_VISIBLE", page) }
    }
"""
            + controller
            + "\n}\n"
        )
        shutil.copy2(
            REPO / "Configs/local/.local/bin/moxi-settings",
            desktop.work / "moxi-settings",
        )
        (desktop.work / "check-launch.py").write_text("""import subprocess,time
from pathlib import Path
log = Path("/work/launcher.log")
def wait_for(marker):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if marker in log.read_text(): return
        time.sleep(0.03)
    raise AssertionError(log.read_text())
with log.open("w") as output:
    server = subprocess.Popen(["qs", "-c", "moxi", "--no-color"], stdout=output, stderr=output)
    try:
        wait_for("Configuration Loaded")
        result = subprocess.run(["bash", "/work/moxi-settings"], capture_output=True, text=True, timeout=5)
        assert result.returncode == 0, result.stderr
        assert "target settings" not in result.stdout, result.stdout
        wait_for("SETTINGS_PANEL_VISIBLE")
        print("SETTINGS_LAUNCHER_OK")
    finally:
        server.terminate()
        server.wait(timeout=3)
""")
        (desktop.work / "run-launch.sh").write_text(
            "mkdir -p /tmp/runtime\nchmod 700 /tmp/runtime\nexec python3 -B /work/check-launch.py\n"
        )
        result = desktop.run(
            "/work/run-launch.sh",
            QT_QPA_PLATFORM="offscreen",
            QT_QUICK_BACKEND="software",
            QML_IMPORT_PATH="/run/current-system/sw/lib/qt-6/qml",
            XDG_RUNTIME_DIR="/tmp/runtime",
            DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/no-bus",
            PULSE_SERVER="unix:/tmp/no-pulse",
            LANG="C.UTF-8",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("SETTINGS_LAUNCHER_OK", result.stdout)

    def test_window_preferences_search_and_page_lifetimes(self):
        self.run_window()

    @unittest.skipUnless(
        shutil.which("Xvfb"), "Xvfb is required for Settings OpenGL checks"
    )
    def test_window_opengl(self):
        self.run_window(opengl=True)

    def test_crossover_capture_cleanup_and_reduced_motion(self):
        self.run_window(crossover=True)

    @unittest.skipUnless(
        shutil.which("Xvfb"), "Xvfb is required for crossover rendering"
    )
    def test_crossover_opengl(self):
        self.run_window(opengl=True, crossover=True)

    @unittest.skipUnless(shutil.which("Xvfb"), "Xvfb is required for popup rendering")
    def test_popup_squircle_blur_and_transitions(self):
        self.run_window(opengl=True, popup=True)

    def run_window(self, opengl=False, crossover=False, popup=False):
        desktop = IsolatedDesktop()
        self.addCleanup(desktop.close)
        shutil.copytree(
            REPO / "Configs/config/.config/quickshell/moxi", desktop.work / "moxi"
        )
        scripts = desktop.home / ".config/hypr/scripts"
        install_preferences(scripts)
        if popup:
            choice = desktop.work / "moxi/settings/SettingsChoice.qml"
            choice.write_text(
                choice.read_text().replace(
                    "id: control\n",
                    "id: control\n\tproperty alias testList: entries\n",
                    1,
                )
            )
        # Tests never connect to host audio devices.
        audio = scripts / "moxi-audio.py"
        device = {
            "id": 3,
            "serial": "103",
            "name": "usb-headset",
            "label": "USB Headset",
            "volume": 42,
            "muted": False,
            "default": True,
            "availability": "available",
            "state": "RUNNING",
            "ports": [
                {
                    "name": "headphones",
                    "description": "Headphones",
                    "availability": "available",
                },
                {
                    "name": "speaker",
                    "description": "Speaker",
                    "availability": "available",
                },
            ],
            "port": "headphones",
        }
        state = {
            "outputs": [device],
            "inputs": [{**device, "id": 4, "serial": "104", "label": "USB Microphone"}],
            "streams": [
                {
                    "id": 9,
                    "serial": "109",
                    "label": "Test player",
                    "detail": "Music",
                    "icon": "",
                    "volume": 60,
                    "muted": False,
                    "sink": 3,
                    "writable": True,
                }
            ],
            "server": "Isolated test audio",
        }
        audio.write_text(
            "import json,time\nprint("
            + repr(json.dumps(state))
            + ",flush=True)\ntime.sleep(30)\n"
        )
        (scripts / "wallpaper-list.sh").write_text("#!/usr/bin/env bash\nexit 0\n")
        shutil.copy2(
            REPO
            / (
                "tests/qml/SettingsPopupScenario.qml"
                if popup
                else "tests/qml/SettingsCrossoverScenario.qml"
                if crossover or popup
                else "tests/qml/SettingsScenario.qml"
            ),
            desktop.work / "shell.qml",
        )
        (desktop.work / "run-settings.sh").write_text(
            "mkdir -p /tmp/runtime\nchmod 700 /tmp/runtime\nexec qs -p /work/shell.qml --no-color\n"
        )
        environment = {
            "QT_QPA_PLATFORM": "offscreen",
            "QT_QUICK_BACKEND": "software",
            "QML_IMPORT_PATH": "/run/current-system/sw/lib/qt-6/qml",
            "XDG_RUNTIME_DIR": "/tmp/runtime",
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=/tmp/no-bus",
            "PULSE_SERVER": "unix:/tmp/no-pulse",
            "LANG": "C.UTF-8",
        }
        if opengl:
            (desktop.work / "run-settings.sh").write_text("""set -euo pipefail
mkdir -p /tmp/runtime
chmod 700 /tmp/runtime
Xvfb :99 -screen 0 1280x900x24 -nolisten tcp >/work/xvfb.log 2>&1 &
server=$!
trap 'kill "$server"; wait "$server" || true' EXIT
for attempt in {1..100}; do
  [[ -S /tmp/.X11-unix/X99 ]] && break
  sleep 0.02
done
qs -p /work/shell.qml --no-color
""")
            environment.update(
                QT_QPA_PLATFORM="xcb",
                QT_QUICK_BACKEND="",
                DISPLAY=":99",
                QSG_RHI_BACKEND="opengl",
                LIBGL_ALWAYS_SOFTWARE="1",
                LIBGL_DRIVERS_PATH=str(Path("/run/opengl-driver/lib/dri").resolve()),
                LD_LIBRARY_PATH=str(Path("/run/opengl-driver/lib").resolve()),
            )
        result = desktop.run("/work/run-settings.sh", **environment)
        output = result.stdout + result.stderr
        self.assertIn(
            "SETTINGS_POPUP_OK"
            if popup
            else "SETTINGS_CROSSOVER_OK"
            if crossover
            else "SETTINGS_SCENARIO_OK",
            output,
        )
        self.assertNotIn("ReferenceError", output)
        self.assertNotIn("TypeError", output)
        self.assertNotIn("Binding loop", output)
        self.assertNotIn("Cannot create delegate", output)
        self.assertNotIn("was not initialized", output)
        images = list(desktop.work.glob("settings-*.png"))
        self.assertEqual(len(images), 1 if popup else 0 if crossover else 7, output)
        if popup:
            raw = subprocess.check_output(
                [
                    "ffmpeg",
                    "-v",
                    "error",
                    "-i",
                    str(images[0]),
                    "-f",
                    "rawvideo",
                    "-pix_fmt",
                    "rgb24",
                    "-",
                ]
            )

            def pixel(x, y):
                offset = (y * 320 + x) * 3
                return tuple(raw[offset : offset + 3])

            # The striped scene is softened behind the menu, while the outer
            # and selected-row corner cutouts retain the pixels beneath them.
            outside = sum(abs(a - b) for a, b in zip(pixel(200, 250), pixel(210, 250)))
            inside = sum(abs(a - b) for a, b in zip(pixel(200, 145), pixel(210, 145)))
            self.assertGreater(outside, 400)
            self.assertLess(inside, 50)
            self.assertEqual(pixel(61, 87), pixel(61, 250))
            for x in (68, 251):
                self.assertEqual(pixel(x, 94), pixel(x, 145))
        capture = os.environ.get("DOTS_SETTINGS_CAPTURE")
        if capture:
            target = Path(capture) / ("opengl" if opengl else "software")
            target.mkdir(parents=True, exist_ok=True)
            (target / "qml.log").write_text(output)
            for image in images:
                shutil.copy2(image, target / image.name)
