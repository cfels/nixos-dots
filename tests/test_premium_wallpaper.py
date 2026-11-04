import concurrent.futures
import importlib.util
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from support import REPO, IsolatedDesktop, install_preferences, install_qml_preferences

HELPER = REPO / "Configs/config/.config/hypr/scripts/premium-wallpaper.py"
sys.path.insert(0, str(HELPER.parent))
SPEC = importlib.util.spec_from_file_location("premium_wallpaper", HELPER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PremiumManifestTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.manifest = self.root / "Velina.premiumwall.json"
        self.data = {"version": 1, "type": "velina"}
        for key in ("opening", "showcase", "poster", "openingPoster", "leafTexture"):
            name = key + " space # asset"
            (self.root / name).write_bytes(b"fixture")
            self.data[key] = name
        self.manifest.write_text(json.dumps(self.data))

    def test_assets_are_local_urls_and_settings_have_defaults(self):
        data = MODULE.describe(self.manifest)
        self.assertIn("%20space%20%23%20asset", data["opening"])
        self.assertTrue(data["startupAudio"])
        self.assertTrue(data["loop"])
        self.assertTrue(data["openingEnabled"])
        self.assertEqual(data["effectsQuality"], "high")

    def test_invalid_settings_and_missing_assets_fail(self):
        for key, value in (
            ("loop", "false"),
            ("effectsQuality", "ultra"),
            ("fit", "stretch"),
            ("opening", "missing.mp4"),
        ):
            with self.subTest(key=key):
                self.manifest.write_text(json.dumps({**self.data, key: value}))
                with self.assertRaises((ValueError, TypeError, OSError)):
                    MODULE.describe(self.manifest)

    def test_claim_survives_reloads_and_audio_has_one_owner(self):
        environment = {
            "XDG_RUNTIME_DIR": str(self.root),
            "HYPRLAND_INSTANCE_SIGNATURE": "first-login",
        }
        with patch.dict(os.environ, environment):
            first = MODULE.claim("DP-1", True)
            self.assertEqual(first, {"opening": True, "audio": True})
            self.assertEqual(
                MODULE.claim("DP-1", True), {"opening": False, "audio": False}
            )
            self.assertEqual(
                MODULE.claim("DP-2", True), {"opening": True, "audio": False}
            )
            os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = "next-login"
            self.assertEqual(MODULE.claim("DP-1", True), first)

    def test_concurrent_claims_are_atomic_and_disabled_audio_does_not_claim(self):
        with patch.dict(
            os.environ,
            {
                "XDG_RUNTIME_DIR": str(self.root),
                "HYPRLAND_INSTANCE_SIGNATURE": "concurrent",
            },
        ):
            with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
                results = list(
                    pool.map(lambda _: MODULE.claim("DP-1", True), range(24))
                )
            self.assertEqual(sum(item["opening"] for item in results), 1)
            self.assertEqual(sum(item["audio"] for item in results), 1)
            os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = "muted"
            self.assertFalse(MODULE.claim("DP-1", False)["audio"])
            self.assertTrue(MODULE.claim("DP-2", True)["audio"])


@unittest.skipUnless(
    all(shutil.which(tool) for tool in ("Xvfb", "pulseaudio", "pactl", "parec")),
    "Xvfb and PulseAudio test tools are required for playback checks",
)
class PremiumPlaybackTests(unittest.TestCase):
    def test_startup_handoff_loops_pause_and_component_reload(self):
        desktop = IsolatedDesktop()
        install_qml_preferences(desktop.work)
        self.addCleanup(desktop.close)
        shutil.copytree(
            REPO / "Configs/config/.config/quickshell/moxi/wallpaper",
            desktop.work / "wallpaper",
        )
        helper = desktop.home / ".config/hypr/scripts/premium-wallpaper.py"
        helper.parent.mkdir(parents=True)
        install_preferences(helper.parent)
        shutil.copy2(HELPER, helper)
        shutil.copy2(
            REPO / "tests/qml/PremiumWallpaperScenario.qml", desktop.work / "shell.qml"
        )
        for name, color, duration, sound in (
            ("opening", "white", "0.7", True),
            ("showcase", "white", "0.6", False),
        ):
            command = [
                "ffmpeg",
                "-v",
                "error",
                "-f",
                "lavfi",
                "-i",
                f"color={color}:s=320x180:r=60:d={duration}",
            ]
            if sound:
                command += [
                    "-f",
                    "lavfi",
                    "-i",
                    f"sine=frequency=440:sample_rate=48000:duration={duration}",
                    "-c:a",
                    "aac",
                ]
            command += [
                "-c:v",
                "libx264",
                "-threads",
                "1",
                "-pix_fmt",
                "yuv420p",
                str(desktop.work / f"{name}.mp4"),
            ]
            subprocess.run(command, check=True, capture_output=True)
        for name, color in (("poster", "blue"), ("opening-poster", "green")):
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
                    str(desktop.work / f"{name}.png"),
                ],
                check=True,
                capture_output=True,
            )
        settings = {
            "version": 1,
            "type": "velina",
            "opening": "opening.mp4",
            "showcase": "showcase.mp4",
            "poster": "poster.png",
            "openingPoster": "opening-poster.png",
            "leafTexture": "poster.png",
        }
        (desktop.work / "Velina.premiumwall.json").write_text(json.dumps(settings))
        (desktop.work / "render.sh").write_text("""#!/usr/bin/env bash
set -euo pipefail
Xvfb :99 -screen 0 640x360x24 -nolisten tcp >/work/xvfb.log 2>&1 &
server=$!
pulseaudio -n --daemonize=no --use-pid-file=no --exit-idle-time=-1 \
    --load='module-native-protocol-unix socket=/tmp/premium-pulse auth-anonymous=1' \
    >/work/pulse.log 2>&1 &
audio=$!
recorder=''
trap 'kill "$server" "$audio" ${recorder:+"$recorder"} 2>/dev/null || true; wait || true' EXIT
for attempt in {1..100}; do
    [[ -S /tmp/.X11-unix/X99 && -S /tmp/premium-pulse ]] && break
    sleep 0.02
done
# Capture only this isolated server, never the desktop's audio.
(
    for attempt in {1..300}; do
        if [[ "$(pactl list short sinks)" == *premium_test* ]]; then
            exec parec --device=premium_test.monitor --format=s16le --rate=48000 --channels=1 --raw >/work/opening-audio.raw
        fi
        sleep 0.02
    done
) &
recorder=$!
qs -p /work/shell.qml --no-color
""")
        multimedia = Path(max(Path("/nix/store").glob("*-qtmultimedia-*/lib/qt-6")))
        try:
            result = desktop.run(
                "/work/render.sh",
                QT_QPA_PLATFORM="xcb",
                QSG_RHI_BACKEND="opengl",
                LIBGL_ALWAYS_SOFTWARE="1",
                DISPLAY=":99",
                QT_MEDIA_BACKEND="ffmpeg",
                XDG_RUNTIME_DIR="/tmp/runtime",
                HYPRLAND_INSTANCE_SIGNATURE="premium-test",
                QML_IMPORT_PATH=str(multimedia / "qml")
                + ":/run/current-system/sw/lib/qt-6/qml",
                QT_PLUGIN_PATH=str(multimedia / "plugins"),
                LIBGL_DRIVERS_PATH=str(Path("/run/opengl-driver/lib/dri").resolve()),
                LD_LIBRARY_PATH=str(Path("/run/opengl-driver/lib").resolve()),
                DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/no-bus",
                PULSE_SERVER="unix:/tmp/premium-pulse",
                LANG="C.UTF-8",
            )
        except subprocess.TimeoutExpired as error:
            self.fail(
                f"playback scenario timed out: {error.stdout[:5000]!r}\n{error.stderr[:5000]!r}"
            )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("PREMIUM_WALLPAPER_OK", output)
        audio = (desktop.work / "opening-audio.raw").read_bytes()
        samples = struct.unpack(f"<{len(audio) // 2}h", audio)
        self.assertGreater(sum(abs(value) > 500 for value in samples), 4000)
        captures = sorted(desktop.work.glob("startup-*.png"))
        self.assertGreater(len(captures), 8)
        for capture in captures:
            pixels = subprocess.check_output(
                [
                    "ffmpeg",
                    "-v",
                    "error",
                    "-i",
                    str(capture),
                    "-vf",
                    "scale=1:1",
                    "-f",
                    "rawvideo",
                    "-pix_fmt",
                    "rgb24",
                    "-threads",
                    "1",
                    "-",
                ]
            )
            self.assertTrue(
                all(value > 235 for value in pixels),
                f"startup exposed a poster or empty frame: {capture.name} {list(pixels)}",
            )
        for error in (
            "TypeError",
            "ReferenceError",
            "Binding loop",
            "Cannot assign",
            "SCENARIO_FAILED",
        ):
            self.assertNotIn(error, output)
