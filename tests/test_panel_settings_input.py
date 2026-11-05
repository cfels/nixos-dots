import re
import shutil
import unittest
from pathlib import Path

from support import REPO, IsolatedDesktop, install_preferences


@unittest.skipUnless(shutil.which("Xvfb"), "Xvfb is required for pointer input checks")
class PanelSettingsInputTests(unittest.TestCase):
    def test_swipes_preserve_controls_and_scroll(self):
        self.run_input()

    def test_real_toggles_and_stock_restore(self):
        self.run_input(controls=True)

    def test_emoji_hover_and_launcher_wheel_scrolling(self):
        self.run_input(pickers=True)

    def run_input(self, controls=False, pickers=False):
        desktop = IsolatedDesktop()
        self.addCleanup(desktop.close)
        shutil.copytree(
            REPO / "Configs/config/.config/quickshell/moxi", desktop.work / "moxi"
        )
        install_preferences(desktop.home / ".config/hypr/scripts")
        (desktop.home / ".config/hypr/scripts/wallpaper-list.sh").write_text(
            "#!/usr/bin/env bash\nexit 0\n"
        )
        if pickers:
            for folder, name, view in (
                ("launcher", "Launcher", "list"),
                ("emoji", "Emoji", "grid"),
            ):
                path = desktop.work / f"moxi/{folder}/{name}.qml"
                text = path.read_text().replace("PanelWindow {", "Item {", 1)
                text = re.sub(
                    r"^\tanchors \{\n(?:\t\t.*\n)+\t}\n",
                    "",
                    text,
                    count=1,
                    flags=re.MULTILINE,
                )
                text = re.sub(
                    r"^\t(?:margins\.top|exclusionMode|WlrLayershell\.\w+|focusable|color|mask):.*\n",
                    "",
                    text,
                    flags=re.MULTILINE,
                )
                text = text.replace(
                    f"id: {folder}\n",
                    f"id: {folder}\n\tproperty alias testView: {view}\n",
                    1,
                )
                path.write_text(text)
        if controls:
            hyprctl = desktop.work / "bin/hyprctl"
            hyprctl.write_text(
                '#!/usr/bin/env bash\nprintf "%s\\n" "$1" >> /work/hyprctl.log\n[[ "$1" != configerrors ]] || printf "ok\\n"\n'
            )
            hyprctl.chmod(0o755)
            row = desktop.work / "moxi/settings/SettingRow.qml"
            row.write_text(
                row.read_text()
                .replace(
                    "checked: row.current === true",
                    'objectName: "toggle:" + row.definition.key\n\t\t\t\tchecked: row.current === true',
                )
                .replace(
                    "id: range",
                    'id: range\n\t\t\t\tobjectName: "slider:" + row.definition.key',
                )
                .replace(
                    "id: choice\n\t\tSettingsChoice {",
                    'id: choice\n\t\tSettingsChoice {\n\t\t\tobjectName: "choice:" + row.definition.key',
                )
            )
            content = desktop.work / "moxi/settings/SettingsContent.qml"
            content.write_text(
                content.read_text().replace(
                    "iconName: modelData.icon",
                    'objectName: "category:" + modelData.key\n\t\t\t\t\t\ticonName: modelData.icon',
                )
            )
        shutil.copy2(
            REPO
            / (
                "tests/qml/PickerInputScenario.qml"
                if pickers
                else "tests/qml/SettingsControlsInputScenario.qml"
                if controls
                else "tests/qml/PanelSettingsInputScenario.qml"
            ),
            desktop.work / "shell.qml",
        )
        shutil.copy2(
            REPO / "tests/panel_settings_input_scenario.py",
            desktop.work / "check-input.py",
        )
        libraries = {}
        for name, pattern in (
            ("X11_TEST_LIBRARY", "*-libx11-*/lib/libX11.so.6"),
            ("XTEST_TEST_LIBRARY", "*-libxtst-*/lib/libXtst.so.6"),
        ):
            libraries[name] = str(
                next(
                    path
                    for path in sorted(Path("/nix/store").glob(pattern))
                    if path.is_file() and path.read_bytes()[:5] == b"\x7fELF\x02"
                )
            )
        (desktop.work / "run.sh").write_text("""#!/usr/bin/env bash
set -euo pipefail
mkdir -p /tmp/runtime
chmod 700 /tmp/runtime
Xvfb :99 -screen 0 1000x740x24 -nolisten tcp >/work/xvfb.log 2>&1 &
server=$!
trap 'kill "$server"; wait "$server" || true' EXIT
for attempt in {1..100}; do
    [[ -S /tmp/.X11-unix/X99 ]] && break
    sleep 0.02
done
python3 /work/check-input.py
""")
        result = desktop.run(
            "/work/run.sh",
            QT_QPA_PLATFORM="xcb",
            QT_QUICK_BACKEND="software",
            DISPLAY=":99",
            XDG_RUNTIME_DIR="/tmp/runtime",
            QML_IMPORT_PATH="/run/current-system/sw/lib/qt-6/qml",
            DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/no-bus",
            LANG="C.UTF-8",
            PANEL_REAL_CONTROLS="1" if controls else "0",
            PANEL_PICKER_CONTROLS="1" if pickers else "0",
            **libraries,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("PANEL_SETTINGS_INPUT_OK", output)
