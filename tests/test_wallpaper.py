import glob
import json
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

from support import REPO, IsolatedDesktop, install_preferences, install_qml_preferences


class WallpaperCommandTests(unittest.TestCase):
    def setUp(self):
        self.desktop = IsolatedDesktop()
        install_qml_preferences(self.desktop.work)
        self.addCleanup(self.desktop.close)
        scripts = self.desktop.repo / "Configs/config/.config/hypr/scripts"
        scripts.mkdir(parents=True)
        install_preferences(scripts)
        for name in ("wallpaper-set.sh", "wallpaper-render.py"):
            shutil.copy2(
                REPO / "Configs/config/.config/hypr/scripts" / name, scripts / name
            )
        for name in ("video.mp4", "still.png", "animated.gif", "bad.png"):
            (self.desktop.work / name).write_text(name)
        cache = self.desktop.home / ".cache"
        cache.mkdir()
        (cache / "current-wallpaper").write_text("/work/still.png\n")
        mock = self.desktop.work / "bin/wallpaper-mock"
        mock.write_text(
            f"#!{sys.executable}\n"
            + """
import json
from pathlib import Path
import sys
import time

name = Path(sys.argv[0]).name
args = sys.argv[1:]
def log(*command):
    with open('/work/wallpaper-commands.jsonl', 'a') as output:
        output.write(json.dumps(command) + '\\n')
log(name, *args)
ready = Path('/work/renderer-ready')
state_path = Path('/work/renderer-state.json')
if name == 'qs':
    if len(args) > 1 and args[1].endswith('/wallpaper/shell.qml'):
        legacy = Path('/work/legacy-renderer')
        if not legacy.exists(): sys.exit(1)
        if args[-1] == 'kill':
            legacy.unlink()
            log('legacy-stop')
        else:
            print('ready')
        sys.exit(0)
    if 'ipc' not in args:
        assert '--no-duplicate' in args, args
        ready.touch()
        time.sleep(0.1)
        sys.exit(0)
    command = args[args.index('wallpaper') + 1:]
    if not ready.exists():
        sys.exit(1)
    if command == ['ping']:
        print('ready')
    elif command[0] == 'set':
        state_path.write_text(json.dumps({'request': command[2], 'path': command[1], 'polls': 0}))
    elif command == ['status']:
        empty = Path('/work/empty-status-once')
        if empty.exists():
            empty.unlink()
            sys.exit(0)
        state = json.loads(state_path.read_text())
        state['polls'] += 1
        state_path.write_text(json.dumps(state))
        failed = state['path'] == '/work/bad.png'
        result = 'failed' if failed else 'ready' if state['polls'] >= 3 else 'loading'
        if result == 'ready':
            log('reveal-complete', state['path'])
        print(json.dumps({'request': state['request'], 'state': result, 'error': 'could not decode wallpaper' if failed else ''}))
    else:
        raise AssertionError(command)
elif name in ('awww', 'swww'):
    assert args == ['kill'], args
elif name == 'ffmpeg':
    Path(args[-1]).write_text('palette frame')
"""
        )
        mock.chmod(0o755)
        for name in ("qs", "awww", "swww", "pkill", "ffmpeg", "matugen", "hyprctl"):
            (self.desktop.work / "bin" / name).symlink_to("wallpaper-mock")

    def run_switches(self, *files):
        entry = self.desktop.work / "switch.sh"
        entry.write_text("""#!/usr/bin/env bash
set -euo pipefail
for file in "$@"; do
    bash /work/repo/Configs/config/.config/hypr/scripts/wallpaper-set.sh "$file" --restore
done
""")
        return self.desktop.run("/work/switch.sh", *files, XDG_RUNTIME_DIR="/tmp")

    def commands(self):
        path = self.desktop.work / "wallpaper-commands.jsonl"
        return (
            [json.loads(line) for line in path.read_text().splitlines()]
            if path.exists()
            else []
        )

    def current(self):
        return (self.desktop.home / ".cache/current-wallpaper").read_text().strip()

    def test_cached_gallery_scan_skips_decoding_and_reuses_atomic_previews(self):
        script = self.desktop.work / "wallpaper-list.sh"
        shutil.copy2(REPO / "Configs/config/.config/hypr/scripts/wallpaper-list.sh", script)
        library = self.desktop.work / "library"
        library.mkdir()
        (library / "video.mp4").write_text("mock video")
        (library / "still.png").write_text("mock image")
        (self.desktop.work / "list.sh").write_text('exec bash /work/wallpaper-list.sh /work/library "$@"\n')

        cold = self.desktop.run("/work/list.sh", "--cached")
        self.assertEqual(cold.returncode, 0, cold.stderr)
        self.assertIn("/work/library/video.mp4\t\t\n", cold.stdout)
        self.assertEqual(self.commands(), [])

        generated = self.desktop.run("/work/list.sh")
        self.assertEqual(generated.returncode, 0, generated.stderr)
        video = next(line.split("\t") for line in generated.stdout.splitlines() if line.startswith("/work/library/video.mp4"))
        self.assertTrue(video[1].endswith(".jpg"), video)
        self.assertTrue(video[2].endswith(".gif"), video)
        commands = self.commands()
        self.assertEqual(len(commands), 2)
        self.assertTrue(all(command[0] == "ffmpeg" and "/." in command[-1] for command in commands))
        self.assertEqual(len(list((self.desktop.home / ".cache/moxi-wallpapers").iterdir())), 2)

        warm = self.desktop.run("/work/list.sh", "--cached")
        self.assertEqual(warm.returncode, 0, warm.stderr)
        self.assertEqual(warm.stdout, generated.stdout)
        self.assertEqual(self.commands(), commands)

    def test_one_renderer_handles_png_video_and_gif(self):
        result = self.run_switches(
            "/work/video.mp4", "/work/still.png", "/work/animated.gif"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        starts = [
            command
            for command in self.commands()
            if command[0] == "qs" and "ipc" not in command
        ]
        self.assertEqual(len(starts), 1)
        self.assertEqual(self.current(), "/work/animated.gif")
        self.assertFalse(any(command[0] == "ffmpeg" for command in self.commands()))

    def test_outgoing_player_is_retired_after_reveal_completion(self):
        result = self.run_switches("/work/still.png")
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.commands()
        complete = commands.index(["reveal-complete", "/work/still.png"])
        stop = next(i for i, command in enumerate(commands) if command[0] == "pkill")
        self.assertLess(complete, stop)
        self.assertLess(complete, commands.index(["awww", "kill"]))

    def test_failed_load_keeps_current_wallpaper_and_legacy_player(self):
        result = self.run_switches("/work/bad.png")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("could not decode wallpaper", result.stderr)
        self.assertEqual(self.current(), "/work/still.png")
        self.assertFalse(
            any(command[0] in ("pkill", "awww", "swww") for command in self.commands())
        )

    def test_empty_status_during_reload_is_retried(self):
        (self.desktop.work / "empty-status-once").touch()
        result = self.run_switches("/work/still.png")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.current(), "/work/still.png")

    def test_nested_entry_is_retired_after_successful_handoff(self):
        (self.desktop.work / "legacy-renderer").touch()
        result = self.run_switches("/work/video.mp4")
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.commands()
        self.assertLess(
            commands.index(["reveal-complete", "/work/video.mp4"]),
            commands.index(["legacy-stop"]),
        )
        self.assertFalse((self.desktop.work / "legacy-renderer").exists())

    def test_missing_file_does_not_start_renderer(self):
        result = self.run_switches("/work/missing.png")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), [])

    def test_palette_refresh_follows_reveal_without_restarting_panel(self):
        entry = self.desktop.work / "theme.sh"
        entry.write_text(
            "bash /work/repo/Configs/config/.config/hypr/scripts/wallpaper-set.sh /work/video.mp4\n"
        )
        result = self.desktop.run("/work/theme.sh", XDG_RUNTIME_DIR="/tmp")
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.commands()
        complete = commands.index(["reveal-complete", "/work/video.mp4"])
        palette = next(
            i for i, command in enumerate(commands) if command[0] == "matugen"
        )
        self.assertLess(complete, palette)
        self.assertFalse(
            any(command[:4] == ["qs", "-c", "moxi", "kill"] for command in commands)
        )


@unittest.skipUnless(
    shutil.which("Xvfb"), "Xvfb is required for wallpaper shader checks"
)
class WallpaperRenderingTests(unittest.TestCase):
    def test_production_renderer_accepts_picker_requests_and_reports_status(self):
        desktop = IsolatedDesktop()
        self.addCleanup(desktop.close)
        shell = desktop.home / ".config/quickshell/moxi"
        shutil.copytree(REPO / "Configs/config/.config/quickshell/moxi", shell)
        scripts = desktop.home / ".config/hypr/scripts"
        install_preferences(scripts)
        for name in ("wallpaper-set.sh", "wallpaper-render.py"):
            shutil.copy2(
                REPO / "Configs/config/.config/hypr/scripts" / name, scripts / name
            )
        # Replace only layer-shell placement; exercise the production root, IPC,
        # preference imports, canvas and picker command with a private display.
        output = shell / "wallpaper/WallpaperOutput.qml"
        text = output.read_text().replace("PanelWindow {", "FloatingWindow {", 1)
        start = text.index("\tanchors {\n")
        end = text.index("\n\tWallpaperCanvas {", start)
        text = (
            text[:start]
            + "\timplicitWidth: 320\n\timplicitHeight: 180\n\tvisible: true\n"
            + text[end:]
        )
        output.write_text(text)
        for color in ("red", "blue"):
            subprocess.run(
                [
                    "ffmpeg",
                    "-v",
                    "error",
                    "-f",
                    "lavfi",
                    "-i",
                    f"color={color}:s=320x180",
                    "-frames:v",
                    "1",
                    "-threads",
                    "1",
                    str(desktop.work / (color + ".png")),
                ],
                check=True,
                capture_output=True,
            )
        (desktop.work / "run-renderer.sh").write_text("""#!/usr/bin/env bash
set -euo pipefail
mkdir -p /tmp/runtime
chmod 700 /tmp/runtime
Xvfb :99 -screen 0 640x480x24 -nolisten tcp >/work/xvfb.log 2>&1 &
server=$!
trap 'python3 "$HOME/.config/hypr/scripts/wallpaper-render.py" --status > /work/final-status.json || true; cp /tmp/runtime/moxi-wallpaper/renderer.log /work/renderer.log 2>/dev/null || true; kill "$server"; wait "$server" || true' EXIT
for attempt in {1..100}; do
    [[ -S /tmp/.X11-unix/X99 ]] && break
    sleep 0.02
done
if python3 "$HOME/.config/hypr/scripts/wallpaper-render.py" --status; then
    exit 1
fi
bash "$HOME/.config/hypr/scripts/wallpaper-set.sh" /work/red.png --restore
bash "$HOME/.config/hypr/scripts/wallpaper-set.sh" /work/blue.png --restore
python3 "$HOME/.config/hypr/scripts/wallpaper-render.py" --status > /work/status.json
""")
        result = desktop.run(
            "/work/run-renderer.sh",
            QT_QPA_PLATFORM="xcb",
            QT_QUICK_BACKEND="",
            DISPLAY=":99",
            XDG_RUNTIME_DIR="/tmp/runtime",
            QSG_RHI_BACKEND="opengl",
            LIBGL_ALWAYS_SOFTWARE="1",
            QML_IMPORT_PATH="/run/current-system/sw/lib/qt-6/qml",
            LIBGL_DRIVERS_PATH=str(Path("/run/opengl-driver/lib/dri").resolve()),
            LD_LIBRARY_PATH=str(Path("/run/opengl-driver/lib").resolve()),
            DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/no-bus",
        )
        log = desktop.work / "renderer.log"
        diagnostic = (
            (desktop.work / "final-status.json").read_text()
            if (desktop.work / "final-status.json").exists()
            else ""
        )
        self.assertEqual(
            result.returncode,
            0,
            result.stdout
            + result.stderr
            + diagnostic
            + (log.read_text() if log.exists() else ""),
        )
        state = json.loads((desktop.work / "status.json").read_text())
        self.assertEqual(state["state"], "ready", state)
        self.assertTrue(
            all(item["path"] == "/work/blue.png" for item in state["outputs"]), state
        )
        self.assertNotIn("ReferenceError", log.read_text())

    def test_grow_geometry_and_live_media_lifetimes(self):
        desktop = IsolatedDesktop()
        install_qml_preferences(desktop.work)
        self.addCleanup(desktop.close)
        source = REPO / "Configs/config/.config/quickshell/moxi/wallpaper"
        shutil.copytree(source, desktop.work / "wallpaper")
        canvas = desktop.work / "wallpaper/WallpaperCanvas.qml"
        canvas.write_text(
            canvas.read_text().replace(
                "id: canvas\n", "id: canvas\n\tproperty alias testReveal: reveal\n", 1
            )
        )
        shutil.copy2(
            REPO / "tests/qml/WallpaperRenderScenario.qml", desktop.work / "shell.qml"
        )
        for name, color in (("red", "red"), ("blue", "blue")):
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-loglevel",
                    "error",
                    "-f",
                    "lavfi",
                    "-i",
                    f"color={color}:s=320x180",
                    "-frames:v",
                    "1",
                    "-threads",
                    "1",
                    str(desktop.work / f"{name}.png"),
                ],
                check=True,
                capture_output=True,
            )
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-v",
                "error",
                "-i",
                str(desktop.work / "red.png"),
                str(desktop.work / "red.jpg"),
            ],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-f",
                "lavfi",
                "-i",
                "color=lime:s=320x180:r=30:d=4",
                "-c:v",
                "libx264",
                "-threads",
                "1",
                "-pix_fmt",
                "yuv420p",
                str(desktop.work / "video.mp4"),
            ],
            check=True,
            capture_output=True,
        )
        shutil.copy2(desktop.work / "video.mp4", desktop.work / "second.mp4")
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-i",
                str(desktop.work / "video.mp4"),
                "-t",
                "1",
                "-vf",
                "fps=10,scale=80:-1",
                str(desktop.work / "animated.gif"),
            ],
            check=True,
            capture_output=True,
        )
        (desktop.work / "bad.png").write_text("invalid image")
        multimedia = Path(max(glob.glob("/nix/store/*-qtmultimedia-*/lib/qt-6")))
        environment = {
            "QT_QPA_PLATFORM": "xcb",
            "QSG_RHI_BACKEND": "opengl",
            "LIBGL_ALWAYS_SOFTWARE": "1",
            "DISPLAY": ":99",
            "QT_MEDIA_BACKEND": "ffmpeg",
            "XDG_RUNTIME_DIR": "/tmp/runtime",
            "QML_IMPORT_PATH": str(multimedia / "qml")
            + ":/run/current-system/sw/lib/qt-6/qml",
            "QT_PLUGIN_PATH": str(multimedia / "plugins"),
            "LIBGL_DRIVERS_PATH": str(Path("/run/opengl-driver/lib/dri").resolve()),
            "LD_LIBRARY_PATH": str(Path("/run/opengl-driver/lib").resolve()),
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=/tmp/no-bus",
            "LANG": "C.UTF-8",
        }
        (desktop.work / "render.sh").write_text("""#!/usr/bin/env bash
set -euo pipefail
Xvfb :99 -screen 0 640x360x24 -nolisten tcp >/work/xvfb.log 2>&1 &
server=$!
trap 'kill "$server"; wait "$server" || true' EXIT
for attempt in {1..100}; do
    [[ -S /tmp/.X11-unix/X99 ]] && break
    sleep 0.02
done
qs -p /work/shell.qml --no-color
""")
        result = desktop.run("/work/render.sh", **environment)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("WALLPAPER_RENDER_OK", output)
        for problem in (
            "TypeError",
            "ReferenceError",
            "Binding loop",
            "Cannot assign",
            "SCENARIO_FAILED",
        ):
            self.assertNotIn(problem, output)
        frames = [
            (f"grow-{corner}.png", corner, (0, 0, 1), (1, 0, 0)) for corner in range(4)
        ]
        frames.append(("grow-video.png", 3, (0, 1, 0), (0, 0, 1)))
        frames.append(("grow-jpg-video.png", 0, (0, 1, 0), (1, 0, 0)))
        for name, corner, incoming, outgoing in frames:
            image = desktop.work / name
            raw = subprocess.run(
                [
                    "ffmpeg",
                    "-v",
                    "error",
                    "-i",
                    str(image),
                    "-f",
                    "rawvideo",
                    "-pix_fmt",
                    "rgb24",
                    "-",
                ],
                check=True,
                capture_output=True,
            ).stdout

            def pixel(x, y, corner=corner, raw=raw):
                x = 319 - x if corner % 2 else x
                y = 179 - y if corner >= 2 else y
                offset = (y * 320 + x) * 3
                return tuple(int(channel > 128) for channel in raw[offset : offset + 3])

            self.assertEqual(pixel(5, 5), incoming, f"{name} origin")
            self.assertEqual(pixel(100, 5), incoming, f"{name} growing circle")
            self.assertEqual(pixel(100, 100), outgoing, f"{name} circular edge")
            self.assertEqual(pixel(315, 175), outgoing, f"{name} outgoing wallpaper")
