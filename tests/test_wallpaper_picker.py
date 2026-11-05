import json
import os
import shutil
import subprocess
import unittest
from pathlib import Path

from support import REPO, IsolatedDesktop, install_preferences, install_qml_preferences


@unittest.skipUnless(shutil.which("Xvfb"), "Xvfb is required for pointer input checks")
class WallpaperPickerTests(unittest.TestCase):
    def test_pointer_hit_testing_scroll_and_animated_premium_preview(self):
        self.run_picker()

    def test_settings_preview_hover_bounds_and_single_scroll_area(self):
        self.run_picker(settings=True)

    def test_settings_opens_with_selected_premium_animation(self):
        self.run_picker(settings=True, selected_premium=True)

    def test_animated_preview_survives_zero_sized_layout(self):
        self.run_picker(image_sizing=True)

    def test_current_selection_preview_reuse_and_premium_options_transition(self):
        self.run_picker(settings=True, selected_premium=True, switching=True)

    def test_current_selection_tracks_first_saved_wallpaper(self):
        self.run_picker(settings=True, switching=True)

    def run_picker(
        self,
        settings=False,
        selected_premium=False,
        image_sizing=False,
        switching=False,
    ):
        desktop = IsolatedDesktop()
        self.addCleanup(desktop.close)
        install_qml_preferences(desktop.work)
        shutil.copytree(
            REPO / "Configs/config/.config/quickshell/moxi/panel",
            desktop.work / "panel",
        )
        shutil.copytree(
            REPO / "Configs/config/.config/quickshell/moxi/components",
            desktop.work / "components",
            dirs_exist_ok=True,
        )
        if settings:
            shutil.copytree(
                REPO / "Configs/config/.config/quickshell/moxi/settings",
                desktop.work / "settings",
                dirs_exist_ok=True,
            )
            shutil.copytree(
                REPO / "Configs/config/.config/quickshell/moxi/assets",
                desktop.work / "assets",
            )
            shutil.copytree(
                REPO / "Configs/config/.config/quickshell/moxi/fonts",
                desktop.work / "fonts",
            )
            content = desktop.work / "settings/SettingsContent.qml"
            content.write_text(
                content.read_text().replace(
                    "id: window\n",
                    "id: window\n\tproperty alias testScroll: content\n\tproperty alias testWallpaper: wallpaperPage.item\n",
                    1,
                )
            )
            page = desktop.work / "settings/WallpapersPage.qml"
            page.write_text(
                page.read_text()
                .replace(
                    "id: page\n",
                    "id: page\n\tproperty alias testLibrary: page.library\n\tproperty alias testView: settingsGallery\n",
                    1,
                )
                .replace(
                    "\tWallpaperView {", "\tWallpaperView {\n\t\tid: settingsGallery", 1
                )
                .replace(
                    "id: page\n",
                    "id: page\n\tproperty alias testOptions: premiumOptions\n",
                    1,
                )
            )
        view = desktop.work / "panel/WallpaperView.qml"
        view.write_text(
            view.read_text()
            .replace(
                "id: wallpaperView\n",
                "id: wallpaperView\n\tproperty alias testGrid: grid\n\tproperty alias testPreview: preview\n\tproperty alias testFrame: previewFrame\n",
                1,
            )
            .replace(
                "delegate: Item {",
                "delegate: Item {\n\t\t\tproperty alias testThumb: thumb",
                1,
            )
        )
        image = desktop.work / "components/SquircleImage.qml"
        image.write_text(
            image.read_text().replace(
                "id: root\n", "id: root\n\tproperty alias testAnimation: animation\n", 1
            )
        )
        scripts = desktop.home / ".config/hypr/scripts"
        scripts.mkdir(parents=True)
        install_preferences(scripts)
        for name in ("wallpaper-list.sh", "premium-wallpaper.py"):
            shutil.copy2(
                REPO / "Configs/config/.config/hypr/scripts" / name, scripts / name
            )
        walls = desktop.home / "walls"
        media = walls / "PremiumWalls/Velina"
        media.mkdir(parents=True)
        for index, color in enumerate(
            ("red", "green", "blue", "yellow", "magenta", "cyan")
        ):
            subprocess.run(
                [
                    "ffmpeg",
                    "-v",
                    "error",
                    "-f",
                    "lavfi",
                    "-i",
                    f"color={color}:s=80x80",
                    "-frames:v",
                    "1",
                    "-threads",
                    "1",
                    str(walls / f"{index:02d}-{color}.png"),
                ],
                check=True,
                capture_output=True,
            )
        subprocess.run(
            [
                "ffmpeg",
                "-v",
                "error",
                "-f",
                "lavfi",
                "-i",
                "testsrc2=s=320x180:r=20:d=2",
                "-c:v",
                "libx264",
                "-threads",
                "1",
                "-pix_fmt",
                "yuv420p",
                str(media / "showcase.mp4"),
            ],
            check=True,
            capture_output=True,
        )
        shutil.copy2(media / "showcase.mp4", media / "opening.mp4")
        shutil.copy2(walls / "00-red.png", media / "poster.png")
        (walls / "Velina.premiumwall.json").write_text(
            json.dumps(
                {
                    "version": 1,
                    "type": "velina",
                    "opening": "PremiumWalls/Velina/opening.mp4",
                    "showcase": "PremiumWalls/Velina/showcase.mp4",
                    "poster": "PremiumWalls/Velina/poster.png",
                    "openingPoster": "PremiumWalls/Velina/poster.png",
                    "leafTexture": "PremiumWalls/Velina/poster.png",
                }
            )
        )
        if selected_premium:
            cache = desktop.home / ".cache"
            cache.mkdir(exist_ok=True)
            (cache / "current-wallpaper").write_text(
                "/home/audituser/walls/Velina.premiumwall.json\n"
            )
        shutil.copy2(
            REPO
            / (
                "tests/qml/WallpaperImageSizingScenario.qml"
                if image_sizing
                else "tests/qml/SettingsWallpaperSwitchScenario.qml"
                if switching
                else "tests/qml/SettingsWallpaperLayoutScenario.qml"
                if settings
                else "tests/qml/WallpaperPickerScenario.qml"
            ),
            desktop.work / "shell.qml",
        )
        library = next(
            path
            for path in sorted(Path("/nix/store").glob("*-libx11-*/lib/libX11.so.6"))
            if path.is_file() and path.read_bytes()[:5] == b"\x7fELF\x02"
        )
        xtst = next(
            path
            for path in sorted(Path("/nix/store").glob("*-libxtst-*/lib/libXtst.so.6"))
            if path.is_file() and path.read_bytes()[:5] == b"\x7fELF\x02"
        )
        (desktop.work / "move-pointer.py").write_text("""import ctypes
import sys
library = ctypes.CDLL(sys.argv[1])
library.XOpenDisplay.argtypes = [ctypes.c_char_p]
library.XOpenDisplay.restype = ctypes.c_void_p
library.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
library.XCloseDisplay.argtypes = [ctypes.c_void_p]
display = library.XOpenDisplay(None)
if not display:
    sys.exit("cannot open isolated test display")
xtst = ctypes.CDLL(sys.argv[2])
xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
if sys.argv[3] == "wheel":
    import time
    xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
    for _ in range(int(sys.argv[5])):
        for pressed in (1, 0):
            if not xtst.XTestFakeButtonEvent(display, int(sys.argv[4]), pressed, 0):
                sys.exit("could not scroll isolated test pointer")
        library.XSync(display, 0)
        time.sleep(0.03)
else:
    if not xtst.XTestFakeMotionEvent(display, -1, int(sys.argv[3]), int(sys.argv[4]), 0):
        sys.exit("could not move isolated test pointer")
library.XSync(display, 0)
library.XCloseDisplay(display)
""")
        (desktop.work / "check-first-scan.py").write_text("""from pathlib import Path
import shutil
rows = [line.split("\\t") for line in Path("/work/first-scan.tsv").read_text().splitlines()]
assert len(rows) == 8, rows
assert all(Path(row[0]).is_file() for row in rows), rows
assert rows[0][0].endswith("!Velina.premiumwall.json"), rows
assert rows[0][2].endswith(".gif") and Path(rows[0][2]).is_file(), rows
shutil.copyfile(rows[0][2], "/work/preview.gif")
""")
        (desktop.work / "run.sh").write_text("""#!/usr/bin/env bash
set -euo pipefail
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp >/work/xvfb.log 2>&1 &
server=$!
trap 'kill "$server"; wait "$server" || true' EXIT
for attempt in {1..100}; do
    [[ -S /tmp/.X11-unix/X99 ]] && break
    sleep 0.02
done
cp "$HOME/walls/Velina.premiumwall.json" "$HOME/walls/!Velina.premiumwall.json"
bash "$HOME/.config/hypr/scripts/wallpaper-list.sh" > /work/first-scan.tsv
python3 /work/check-first-scan.py
unlink "$HOME/walls/!Velina.premiumwall.json"
qs -p /work/shell.qml --no-color
""")
        render = {}
        if settings:
            render = {
                "QSG_RHI_BACKEND": "opengl",
                "LIBGL_ALWAYS_SOFTWARE": "1",
                "LIBGL_DRIVERS_PATH": str(Path("/run/opengl-driver/lib/dri").resolve()),
                "LD_LIBRARY_PATH": str(Path("/run/opengl-driver/lib").resolve()),
            }
        result = desktop.run(
            "/work/run.sh",
            QT_QPA_PLATFORM="offscreen" if image_sizing else "xcb",
            QT_QUICK_BACKEND="" if settings else "software",
            DISPLAY=":99",
            XDG_RUNTIME_DIR="/tmp/runtime",
            QML_IMPORT_PATH="/run/current-system/sw/lib/qt-6/qml",
            DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/no-bus",
            X11_TEST_LIBRARY=str(library),
            XTEST_TEST_LIBRARY=str(xtst),
            LANG="C.UTF-8",
            **render,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("WALLPAPER_PICKER_OK", output)
        for error in (
            "PICKER_FAILED",
            "TypeError",
            "ReferenceError",
            "Binding loop",
            "Cannot assign",
        ):
            self.assertNotIn(error, output)
        capture = os.environ.get("DOTS_PICKER_CAPTURE")
        if settings and capture:
            target = Path(capture)
            target.mkdir(parents=True, exist_ok=True)
            (target / "picker.log").write_text(output)
            for image in desktop.work.glob("settings-gallery-*.png"):
                shutil.copy2(image, target / image.name)
