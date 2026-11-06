import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from support import REPO
from test_lyrics_panel import block_after

SCRIPTS = REPO / "Configs/config/.config/hypr/scripts"
sys.path.insert(0, str(SCRIPTS))
import moxi_settings as settings


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


audio = module("moxi_audio", SCRIPTS / "moxi-audio.py")


class SettingsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        environment = patch.dict(
            os.environ,
            {"HOME": str(self.home), "XDG_CONFIG_HOME": str(self.home / ".config")},
        )
        environment.start()
        self.addCleanup(environment.stop)

    def change(self, key, value, wallpaper=""):
        document, values, _ = settings.load()
        expected = (
            document.get("wallpapers", {}).get(wallpaper, {}).get(key)
            if wallpaper
            else values[key]
        )
        return settings.patch(
            {
                "changes": {key: value},
                "expected": {key: expected},
                "wallpaper": wallpaper,
            }
        )

    def test_missing_preferences_use_current_defaults_without_writing(self):
        self.assertEqual(settings.get("wallpaper.revealDuration"), 450)
        self.assertEqual(settings.get("appearance.shellOpacity"), 1)
        self.assertEqual(settings.get("advanced.motionSamples"), 32)
        self.assertFalse(settings.settings_path().exists())

    def restore(self, category=None, expected=None):
        return settings.restore(
            {"category": category, "expected": expected or settings.load()[0]}
        )

    def test_screen_corners_persist_validate_and_reset_without_hyprland_changes(self):
        self.assertTrue(settings.get("appearance.screenCorners"))
        self.assertEqual(settings.get("appearance.screenCornerRadius"), 24)
        self.change("appearance.screenCorners", False)
        self.change("appearance.screenCornerRadius", 36)
        self.assertFalse(settings.get("appearance.screenCorners"))
        self.assertEqual(settings.get("appearance.screenCornerRadius"), 36)
        for invalid in (0, 65, 12.5, True, "24"):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                self.change("appearance.screenCornerRadius", invalid)
        self.assertNotIn("screenCorner", settings.generate_hyprland().read_text())
        self.restore("appearance")
        self.assertTrue(settings.get("appearance.screenCorners"))
        self.assertEqual(settings.get("appearance.screenCornerRadius"), 24)

    def test_restore_all_is_persistent_and_preserves_personal_files(self):
        wallpaper = self.home / "Velina.premiumwall.json"
        wallpaper.write_text("wallpaper asset")
        self.change("appearance.gapsIn", 18)
        self.change("notifications.dnd", True)
        self.change("premium.startupAudio", False, str(wallpaper))
        self.assertTrue(self.restore())
        document, values, _ = settings.load()
        self.assertEqual(document["values"], {})
        self.assertEqual(document["wallpapers"], {})
        self.assertEqual(values, settings.defaults())
        self.assertEqual(wallpaper.read_text(), "wallpaper asset")
        self.assertNotIn("gaps_in", settings.generate_hyprland().read_text())

    def test_category_restore_is_atomic_and_keeps_other_categories(self):
        self.change("bar.visualizer", False)
        self.change("bar.media", False)
        self.change("appearance.gapsIn", 16)
        with patch.object(
            settings, "atomic_write", wraps=settings.atomic_write
        ) as write:
            self.assertFalse(self.restore("bar"))
            self.assertEqual(write.call_count, 1)
        self.assertTrue(settings.get("bar.visualizer"))
        self.assertTrue(settings.get("bar.media"))
        self.assertEqual(settings.get("appearance.gapsIn"), 16)

    def test_restore_rejects_concurrent_changes_and_keeps_corrupt_json(self):
        self.change("bar.media", False)
        before = settings.load()[0]
        self.change("bar.media", True)
        with self.assertRaisesRegex(ValueError, "externally"):
            self.restore("bar", before)
        settings.settings_path().write_text("{broken")
        with self.assertRaises(ValueError):
            self.restore(expected=before)
        self.assertEqual(settings.settings_path().read_text(), "{broken")

    def test_wallpaper_category_restore_covers_all_manifests(self):
        for name in ("one", "two"):
            self.change(
                "premium.startupAudio",
                False,
                str(self.home / (name + ".premiumwall.json")),
            )
        self.change("bar.media", False)
        self.restore("wallpaper")
        self.assertEqual(settings.load()[0]["wallpapers"], {})
        self.assertFalse(settings.get("bar.media"))

    def test_stock_hyprland_defaults_match_shipped_configuration(self):
        import re

        root = REPO / "Configs/config/.config/hypr/hyprland"
        looks = (root / "looks.lua").read_text()
        input_config = (root / "input.lua").read_text()
        for key, location in settings.HYPRLAND.items():
            if location[-1] == "enabled":
                block = re.search(r"\b" + location[-2] + r"\s*=\s*\{([^}]+)", looks)[1]
                stock = re.search(r"\benabled\s*=\s*(true|false)", block)[1] == "true"
            else:
                source = input_config if location[0] == "input" else looks
                literal = re.search(r"\b" + location[-1] + r"\s*=\s*([^,\n]+)", source)[
                    1
                ].strip()
                stock = {"true": True, "false": False}.get(literal)
                if stock is None:
                    stock = json.loads(literal)
            self.assertEqual(settings.defaults()[key], stock, key)

    def test_rice_version_formats_current_subject_and_hash_and_handles_missing_metadata(
        self,
    ):
        helper = module("settings_cli", SCRIPTS / "moxi-settings.py")
        subject = subprocess.check_output(
            ["git", "-C", str(REPO), "log", "-1", "--format=%s"], text=True
        ).strip()
        commit = subprocess.check_output(
            ["git", "-C", str(REPO), "rev-parse", "--short", "HEAD"], text=True
        ).strip()
        self.assertEqual(
            helper.project_info(), {"commit": f"{subject} (commit:  {commit})"}
        )
        with patch.object(
            helper, "__file__", str(self.home / "installed/moxi-settings.py")
        ):
            self.assertIn("missing", helper.project_info()["commit"])

    @unittest.skipUnless(
        shutil.which("bun"), "Bun is required for the launcher integration check"
    )
    def test_launcher_excludes_settings_and_preserves_applications(self):
        source = (
            REPO / "Configs/config/.config/quickshell/moxi/launcher/Launcher.qml"
        ).read_text()
        body = block_after(source, "function buildIndex(")
        script = """
globalThis.Quickshell = { shellDir: "/shell" };
globalThis.DesktopEntries = { applications: { values: [] } };
globalThis.launcher = { resultLimit: 200, requested: false, settingsRequested() { this.requested = true; } };
const build = new Function(BODY);
build();
if (launcher.index.length !== 0) throw new Error("Settings app was added");
DesktopEntries.applications.values = [{ id: "moxi-settings.desktop", name: "Moxi Settings" }, {id: "kitty.desktop", name: "Kitty"}];
build();
if (launcher.index.length !== 1 || launcher.index[0].entry.name !== "Kitty") throw new Error("Settings leaked into launcher or applications were removed");
""".replace("BODY", json.dumps(body))
        result = subprocess.run(
            ["bun", "-e", script],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_persistence_reset_and_no_credentials(self):
        self.change("bar.visualizer", False)
        output = subprocess.check_output(
            [sys.executable, "-B", str(SCRIPTS / "moxi-settings.py"), "read"], text=True
        )
        self.assertFalse(json.loads(output)["values"]["bar.visualizer"])
        self.change("bar.visualizer", None)
        self.assertTrue(settings.load()[1]["bar.visualizer"])
        self.assertNotIn("bar.visualizer", settings.load()[0]["values"])
        with self.assertRaises(ValueError):
            settings.validate("APPLE_MUSIC_TOKEN", "secret")

    def test_invalid_json_is_preserved_and_scripts_use_defaults(self):
        settings.directory().mkdir(parents=True)
        settings.settings_path().write_text("{broken")
        with self.assertRaises(ValueError):
            self.change("bar.visualizer", False)
        self.assertEqual(settings.settings_path().read_text(), "{broken")
        self.assertTrue(settings.get("bar.visualizer"))

    def test_validation_rejects_wrong_types_ranges_and_paths(self):
        for key, value in [
            ("bar.visualizer", 1),
            ("appearance.gapsIn", True),
            ("appearance.gapsIn", 4.5),
            ("appearance.activeOpacity", float("nan")),
            ("advanced.motionSamples", 1000),
            ("wallpaper.fit", "stretch"),
            ("desktop.screenshotDirectory", "relative"),
            ("desktop.keyboardLayout", 'pl");os.execute("bad")'),
        ]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                settings.validate(key, value)

    def test_unrelated_external_edits_are_merged_but_conflicts_fail(self):
        self.change("bar.visualizer", False)
        request = {
            "changes": {"bar.visualizer": True},
            "expected": {"bar.visualizer": False},
        }
        self.change("bar.media", False)
        settings.patch(request)
        self.assertFalse(settings.get("bar.media"))
        with self.assertRaisesRegex(ValueError, "externally"):
            settings.patch(request)

    def test_atomic_write_failure_keeps_existing_file(self):
        self.change("bar.visualizer", False)
        before = settings.settings_path().read_text()
        with (
            patch.object(Path, "replace", side_effect=OSError("disk failure")),
            self.assertRaises(OSError),
        ):
            self.change("bar.visualizer", True)
        self.assertEqual(settings.settings_path().read_text(), before)
        self.assertEqual(list(settings.directory().glob(".moxi-*")), [])

    def test_premium_preferences_do_not_modify_manifest_or_reservations(self):
        manifest = self.home / "Velina.premiumwall.json"
        manifest.write_text('{"version": 1}')
        self.change("premium.startupAudio", False, str(manifest))
        self.assertEqual(
            settings.premium_overrides(manifest), {"premium.startupAudio": False}
        )
        self.assertEqual(manifest.read_text(), '{"version": 1}')
        self.change("premium.startupAudio", None, str(manifest))
        self.assertEqual(settings.premium_overrides(manifest), {})

    def test_generated_lua_is_separate_and_uses_only_validated_overrides(self):
        self.change("appearance.gapsIn", 12)
        self.change("desktop.keyboardLayout", "pl,us")
        self.change("bar.media", False)
        path = settings.generate_hyprland()
        text = path.read_text()
        self.assertIn("hl.config({ general = { gaps_in = 12 }", text)
        self.assertIn('kb_layout = "pl,us"', text)
        self.assertNotIn("bar", text)
        self.change("appearance.gapsIn", None)
        self.assertNotIn("gaps_in", settings.generate_hyprland().read_text())

    def test_legacy_dnd_import_is_not_reimported_after_reset(self):
        (self.home / ".cache").mkdir()
        (self.home / ".cache/moxi-dnd").touch()
        self.assertTrue(settings.get("notifications.dnd"))
        self.change("bar.visualizer", False)
        self.assertTrue(settings.get("notifications.dnd"))
        self.change("notifications.dnd", None)
        self.assertFalse(settings.get("notifications.dnd"))

    def test_concurrent_writers_preserve_distinct_preferences(self):
        commands = []
        for key in ("bar.visualizer", "bar.media"):
            request = json.dumps({"changes": {key: False}, "expected": {key: True}})
            commands.append(
                subprocess.Popen(
                    [
                        sys.executable,
                        "-B",
                        str(SCRIPTS / "moxi-settings.py"),
                        "patch",
                        request,
                    ],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
            )
        for process in commands:
            _stdout, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, stderr)
        self.assertFalse(settings.get("bar.visualizer"))
        self.assertFalse(settings.get("bar.media"))


class AudioAdapterTests(unittest.TestCase):
    def test_subscription_only_publishes_changed_snapshots(self):
        initial = self.state()
        changed = {**initial, "inputs": [{"id": 4, "serial": "104"}]}
        process = Mock()
        selector = Mock()
        clock = [0.0]
        calls = [0]
        key = Mock()

        def events(timeout):
            calls[0] += 1
            clock[0] += 0.1
            if calls[0] > 4:
                raise RuntimeError("End of test events")
            return [(key, 1)] if calls[0] % 2 else []

        selector.select.side_effect = events
        with (
            patch.object(audio.signal, "signal"),
            patch.object(audio.subprocess, "Popen", return_value=process),
            patch.object(audio.selectors, "DefaultSelector") as factory,
            patch.object(audio.os, "read", return_value=b"Event 'change' on sink #3\n"),
            patch.object(audio.time, "monotonic", side_effect=lambda: clock[0]),
            patch.object(audio, "snapshot", side_effect=[initial, initial, changed]),
            patch.object(audio, "emit") as emit,
        ):
            factory.return_value.__enter__.return_value = selector
            with self.assertRaisesRegex(RuntimeError, "End of test events"):
                audio.watch()
            self.assertEqual(
                [call.args[0] for call in emit.call_args_list], [initial, changed]
            )
            process.terminate.assert_called_once()

    def state(self):
        return {
            "outputs": [{"id": 3, "serial": "103", "name": "usb-headset", "ports": []}],
            "inputs": [],
            "streams": [{"id": 9, "serial": "109"}],
        }

    def test_stream_route_uses_real_output_and_rejects_removed_objects(self):
        with (
            patch.object(audio, "snapshot", return_value=self.state()),
            patch.object(audio, "pactl") as call,
        ):
            audio.command(
                {
                    "action": "route",
                    "kind": "sink-input",
                    "id": 9,
                    "serial": "109",
                    "value": 3,
                }
            )
            call.assert_called_once_with("move-sink-input", "9", "usb-headset")
            with self.assertRaises(ValueError):
                audio.command(
                    {
                        "action": "route",
                        "kind": "sink-input",
                        "id": 9,
                        "serial": "old",
                        "value": 3,
                    }
                )
            with self.assertRaises(ValueError):
                audio.command(
                    {
                        "action": "route",
                        "kind": "sink-input",
                        "id": 9,
                        "serial": "109",
                        "value": 8,
                    }
                )

    def test_volume_is_backend_state_and_commands_are_bounded(self):
        self.assertEqual(
            audio.volume(
                {"volume": {"left": {"value": 32768}, "right": {"value": 32768}}}
            ),
            50,
        )
        self.assertIsNone(audio.volume({}))
        with (
            patch.object(audio, "snapshot", return_value=self.state()),
            patch.object(audio, "pactl") as call,
        ):
            audio.command(
                {
                    "action": "volume",
                    "kind": "sink",
                    "id": 3,
                    "serial": "103",
                    "value": 42,
                }
            )
            call.assert_called_once_with("set-sink-volume", "3", "42%")
            for value in (-1, 151, float("nan"), True):
                with self.assertRaises(ValueError):
                    audio.command(
                        {
                            "action": "volume",
                            "kind": "sink",
                            "id": 3,
                            "serial": "103",
                            "value": value,
                        }
                    )

    def test_external_defaults_and_port_availability_are_reflected(self):
        node = {
            "index": 7,
            "name": "hdmi",
            "description": "Display",
            "active_port": "hdmi-1",
            "ports": [{"name": "hdmi-1", "availability": "not available"}],
            "mute": True,
        }
        result = audio.device(node, "hdmi")
        self.assertTrue(result["default"])
        self.assertTrue(result["muted"])
        self.assertEqual(result["availability"], "not available")
        self.assertFalse(audio.device(node, "usb")["default"])
