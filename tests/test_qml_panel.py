import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from support import REPO, IsolatedDesktop, install_preferences
from test_lyrics_panel import block_after


class QmlPanelTests(unittest.TestCase):
    def test_audio_events_only_refresh_changed_controls(self):
        self.run_scenario(REPO / "tests/qml/AudioUpdatesScenario.qml")

    @unittest.skipUnless(
        shutil.which("Xvfb") and shutil.which("fc-match"),
        "Xvfb and Fontconfig are required for text rendering",
    )
    def test_bar_text_merges_scripts_and_uses_native_hinting_at_rest(self):
        images = self.run_scenario(
            REPO / "tests/qml/BarTextScenario.qml", renderer="opengl", with_fonts=True
        )
        self.assertIn("panel-bar-text.png", images)
        capture = os.environ.get("DOTS_PANEL_CAPTURE")
        if capture:
            directory = Path(capture)
            directory.mkdir(parents=True, exist_ok=True)
            (directory / "bar-text.png").write_bytes(images["panel-bar-text.png"])

    def test_settings_success_messages_expire_but_errors_remain(self):
        self.run_scenario(REPO / "tests/qml/SettingsMessagesScenario.qml")

    def test_settings_messages_fade_collapse_and_preserve_errors(self):
        self.run_scenario(REPO / "tests/qml/SettingsMessageAnimationScenario.qml")

    @unittest.skipUnless(shutil.which("Xvfb"), "Xvfb is required for message rendering")
    def test_settings_message_layout_animation_opengl(self):
        self.run_scenario(
            REPO / "tests/qml/SettingsMessageAnimationScenario.qml", renderer="opengl"
        )

    @unittest.skipUnless(shutil.which("Xvfb"), "Xvfb is required for exit rendering")
    def test_settings_exit_freezes_layout_and_releases_its_gpu_source(self):
        images = self.run_scenario(
            REPO / "tests/qml/PanelExitScenario.qml", renderer="opengl"
        )
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "exit.png"
            image.write_bytes(images["panel-settings-exit.png"])
            pixels = subprocess.check_output(
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
                ]
            )
        # The live page turned green after capture; its frozen blue frame must remain.
        offset = (100 * 380 + 300) * 3
        red, green, blue = pixels[offset : offset + 3]
        self.assertGreater(blue, 30, (red, green, blue))
        self.assertLess(green, 5, (red, green, blue))

    @unittest.skipUnless(
        shutil.which("Xvfb"), "Xvfb is required for fade and corner rendering"
    )
    def test_lyrics_fade_screen_corners_and_interrupted_island_close(self):
        images = self.run_scenario(
            REPO / "tests/qml/ShellPolishScenario.qml",
            renderer="opengl",
            with_island=True,
        )
        with tempfile.TemporaryDirectory() as directory:
            pixels = {}
            for name, data in images.items():
                image = Path(directory) / name
                image.write_bytes(data)
                pixels[name] = subprocess.check_output(
                    [
                        "ffmpeg",
                        "-v",
                        "error",
                        "-i",
                        str(image),
                        "-f",
                        "rawvideo",
                        "-pix_fmt",
                        "rgba",
                        "-",
                    ]
                )
            corners = pixels["panel-screen-corners.png"]
            for x, y in ((0, 0), (127, 0), (0, 127), (127, 127)):
                self.assertLess(corners[(y * 128 + x) * 4], 5)
            self.assertGreater(corners[(64 * 128 + 64) * 4], 250)
            fade = pixels["panel-lyrics-fade.png"]
            height = len(fade) // (310 * 4)
            values = [
                fade[(y * 310 + 155) * 4 + 3]
                for y in (7, 16, height // 2, height - 17, height - 8)
            ]
            self.assertLess(values[0], values[1])
            self.assertLess(values[1], values[2] - 20)
            self.assertGreater(values[2], 245)
            self.assertLess(values[4], values[3])
            self.assertLess(values[3], values[2] - 20)

    def test_settings_panel_swipes_and_lifecycle(self):
        self.run_scenario(REPO / "tests/qml/PanelSettingsScenario.qml")

    def test_optional_sections_resize_standalone_and_island_panels(self):
        images = self.run_scenario(REPO / "tests/qml/PanelSectionsScenario.qml", with_island=True)
        self.assertEqual(len(images), 8)
        capture = os.environ.get("DOTS_PANEL_CAPTURE")
        if capture:
            target = Path(capture)
            target.mkdir(parents=True, exist_ok=True)
            for name, data in images.items():
                (target / name).write_bytes(data)

    def test_panel_runtime(self):
        self.run_scenario(REPO / "tests/qml/PanelScenario.qml")

    def test_stowed_layout(self):
        self.run_scenario(REPO / "tests/qml/PanelScenario.qml", installed_layout=True)

    def test_existing_player_on_load(self):
        self.run_scenario(REPO / "tests/qml/PanelScenario.qml", initial_player=True)

    def test_wallpaper_directory_changes_without_reload(self):
        self.run_scenario(REPO / "tests/qml/WallpaperScenario.qml", real_wallpapers=True)

    def test_wallpaper_cached_list_precedes_preview_generation(self):
        self.run_scenario(REPO / "tests/qml/WallpaperLoadingScenario.qml", progressive_wallpapers=True)

    def test_theme_colors_update_without_shell_reload(self):
        self.run_scenario(REPO / "tests/qml/ThemeScenario.qml")

    def test_panel_with_real_artwork_fetcher(self):
        self.run_scenario(REPO / "tests/qml/PanelScenario.qml", real_artwork=True)

    def test_artwork_refresh_does_not_reanimate(self):
        self.run_scenario(REPO / "tests/qml/ArtworkScenario.qml")

    @unittest.skipUnless(
        shutil.which("Xvfb"), "Xvfb is required for artwork transition rendering"
    )
    def test_artwork_transitions_keep_previous_cover(self):
        images = self.run_scenario(
            REPO / "tests/qml/ArtworkTransitionScenario.qml", renderer="opengl"
        )
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "artwork.png"
            image.write_bytes(images["panel-artwork-mid.png"])
            raw = subprocess.check_output(
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
                ]
            )
        for x, expected in ((20, (171, 52, 86)), (145, (86, 171, 52))):
            offset = (83 * 166 + x) * 3
            actual = raw[offset : offset + 3]
            self.assertTrue(
                all(abs(a - b) <= 5 for a, b in zip(actual, expected)),
                (x, tuple(actual), expected),
            )

    def test_browser_artwork_refresh_without_track_url(self):
        self.run_scenario(REPO / "tests/qml/BrowserArtworkScenario.qml", real_artwork=True)

    @unittest.skipUnless(shutil.which("Xvfb"), "Xvfb is required for artwork masking")
    def test_artwork_corners_stay_masked_when_returning_from_lyrics(self):
        images = self.run_scenario(
            REPO / "tests/qml/ArtworkLyricsCornersScenario.qml", renderer="opengl"
        )
        self.assertEqual(len(images), 10)
        visible_frames = 0
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "artwork.png"
            for name, data in images.items():
                image.write_bytes(data)
                raw = subprocess.check_output(
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
                    ]
                )
                # Compare to the center: visibility/opacity differs across the fade.
                center = raw[(85 * 170 + 85) * 3]
                if center == 0:
                    continue
                visible_frames += 1
                for x, y in ((3, 3), (166, 3), (3, 166), (166, 166)):
                    corner = raw[(y * 170 + x) * 3]
                    self.assertLessEqual(
                        corner, max(3, center * 0.02), (name, x, y, corner, center)
                    )
        self.assertGreaterEqual(visible_frames, 8)

    def test_search_progress_preserves_animation_position(self):
        self.run_scenario(REPO / "tests/qml/SearchProgressScenario.qml")

    def test_panel_visual_states(self):
        images = self.run_scenario(REPO / "tests/qml/PanelVisualScenario.qml")
        self.assertEqual(set(images), {"panel-" + name + ".png" for name in ("idle", "artwork", "synced", "plain", "hosted", "collapsed")})
        self.assertTrue(all(data.startswith(b"\x89PNG\r\n\x1a\n") for data in images.values()))
        self.assertNotEqual(images["panel-idle.png"], images["panel-artwork.png"])
        self.assertNotEqual(images["panel-plain.png"], images["panel-hosted.png"])
        self.assertNotEqual(images["panel-idle.png"], images["panel-collapsed.png"])

    @unittest.skipUnless(shutil.which("Xvfb"), "Xvfb is required for isolated OpenGL rendering")
    def test_panel_opengl_states(self):
        images = self.run_scenario(REPO / "tests/qml/PanelVisualScenario.qml", renderer="opengl")
        self.assertEqual(len(images), 6)
        self.assertEqual(len(set(images.values())), 6)

    def run_scenario(self, scenario, source=None, renderer="software", initial_player=False, installed_layout=False, real_artwork=False, real_wallpapers=False, progressive_wallpapers=False, with_island=False, with_fonts=False):
        desktop = IsolatedDesktop()
        self.addCleanup(desktop.close)
        source = source or REPO / "Configs/config/.config/quickshell/moxi"
        target = desktop.work / "moxi"
        shutil.copytree(source, target)
        pager = target / "panel/PanelPager.qml"
        pager.write_text(pager.read_text().replace("id: pager\n", "id: pager\n\tproperty alias testSettings: settings\n\tproperty alias testExit: outgoingSettings\n", 1))
        if with_island:
            island = target / "components/IslandWindow.qml"
            text = island.read_text().replace("PanelWindow {", "Item {", 1)
            text = re.sub(r'^\tanchors \{[^\n]*\}\n', '', text, count=1, flags=re.MULTILINE)
            text = re.sub(r'^\t(?:screen|margins\.top|exclusionMode|WlrLayershell\.\w+|focusable|color|mask):.*\n', '', text, flags=re.MULTILINE)
            text = text.replace("id: island\n", "id: island\n\tproperty alias testSurface: surface\n", 1)
            island.write_text(text)
        panel = target / "panel/Panel.qml"
        # PanelWindow needs a compositor; only the test copy uses an ordinary Qt window.
        text = panel.read_text().replace("PanelWindow {", "Item {", 1)
        text = re.sub(r'\n\tanchors \{\n\t\ttop: true\n\t\tleft: true\n\t\tright: true\n\t\}', '', text, count=1)
        text = re.sub(r'^\tmask: Region \{[\s\S]*?^\t}\n', '', text, flags=re.M)
        text = re.sub(r'^\t(?:margins\.top|exclusionMode|color|mask):.*\n', '', text, flags=re.M)
        aliases = {
            "testMedia": "playerController" if (target / "panel/PlayerController.qml").exists() else "panel",
            "testLyrics": "lyricsController" if (target / "panel/LyricsController.qml").exists() else "panel",
            "testArtwork": "artworkController" if (target / "panel/ArtworkController.qml").exists() else "panel",
            "testWallpaper": "wallpaperController" if (target / "panel/WallpaperController.qml").exists() else "panel",
            "testTimeline": "playerView.testTimeline",
            "testLyricsView": "playerView.testLyricsView",
            "testArtworkView": "playerView.testArtworkView",
            "testSurface": "cardSource",
            "testCalendar": "calendar",
            "testPager": "pager",
            "testPlayerView": "playerView",
            "testWallpaperView": "wallpaperView",
        }
        text = text.replace("\tid: panel\n", "\tid: panel\n" + ''.join(f'\tproperty alias {key}: {value}\n' for key, value in aliases.items()), 1)
        lyrics_view = target / "panel/LyricsView.qml"
        if lyrics_view.exists():
            lyrics_view.write_text(lyrics_view.read_text().replace("id: lyricsDisplay\n", "id: lyricsDisplay\n\tproperty alias testList: lyricsView\n", 1))
        player_view = target / "panel/PlayerView.qml"
        if player_view.exists():
            player_view.write_text(player_view.read_text().replace("id: playerView\n", "id: playerView\n\tproperty alias testTimeline: progressTrack\n\tproperty alias testLyricsView: lyricsView.testList\n\tproperty alias testArtworkView: artwork\n", 1).replace("id: progressTrack\n", "id: progressTrack\n\t\tproperty alias testSweep: progressFill.sweep\n", 1))
            artwork_view = target / "panel/ArtworkView.qml"
            artwork_view.write_text(artwork_view.read_text().replace("id: artwork\n", "id: artwork\n\tproperty int testTransitions: 0\n\tproperty alias testSwap: artSwap\n\tproperty alias testFirst: artworkOut\n\tproperty alias testSecond: artworkIn\n", 1).replace("id: artSwap\n", "id: artSwap\n\t\tonStarted: artwork.testTransitions += 1\n", 1))
        else:
            text = text.replace("playerView.testTimeline", "progressTrack").replace("playerView.testLyricsView", "lyricsView")
        panel.write_text(text)
        settings_content = target / "settings/SettingsContent.qml"
        settings_content.write_text(settings_content.read_text().replace(
            "id: window\n", "id: window\n\tproperty alias testCrossover: pageCrossover\n\tproperty alias testStatus: statusMessage\n", 1
        ))
        wallpaper_controller = target / "panel/WallpaperController.qml"
        wallpaper_controller.write_text(wallpaper_controller.read_text().replace(
            "id: wallpapers\n", "id: wallpapers\n\tproperty alias testScan: scan\n", 1
        ))
        media = target / "panel/PlayerController.qml"
        if not media.exists():
            media = panel
        text = media.read_text()
        replacement = 'property var player: TestFixtures.FakePlayer { trackTitle: "Startup" }' if initial_player else 'property var player: null'
        text, replacements = re.subn(r'readonly property var player: \w+\.pickPlayer\(\)', replacement, text)
        if initial_player:
            text = 'import "../.." as TestFixtures\n' + text
        self.assertEqual(replacements, 1)
        media.write_text(text)
        home_config = desktop.home / ".config/quickshell"
        home_config.mkdir(parents=True)
        deployment = ""
        if installed_layout:
            package = desktop.repo / "Configs/config/.config/quickshell/moxi"
            package.parent.mkdir(parents=True)
            shutil.move(target, package)
            installed = home_config / "moxi"
            (installed / "panel").mkdir(parents=True)
            for name in ("Panel.qml", "Calendar.qml", "Marquee.qml"):
                (installed / "panel" / name).symlink_to(os.path.relpath("/work/repo/Configs/config/.config/quickshell/moxi/panel/" + name, "/home/audituser/.config/quickshell/moxi/panel"))
            target.symlink_to("/home/audituser/.config/quickshell/moxi")
            deployment = '''set -e
[[ ! -e /home/audituser/.config/quickshell/moxi/panel/PlayerView.qml ]]
stow --restow --dir=/work/repo/Configs --target=/home/audituser config
for component in PlayerController PlayerView LyricsController LyricsView ArtworkController ArtworkView WallpaperController WallpaperView PanelFonts; do
  [[ -f /home/audituser/.config/quickshell/moxi/panel/$component.qml ]]
done
'''
        else:
            (home_config / "moxi").symlink_to("/work/moxi")
        scripts = desktop.home / ".config/hypr/scripts"
        scripts.mkdir(parents=True)
        install_preferences(scripts)
        if installed_layout:
            # Stow must publish its own schema, just like the remaining QML components.
            (home_config / "moxi/settings/schema.json").unlink()
        mocks = {
            "wallpaper-list.sh": 'cat /work/wallpapers.tsv',
            "wallpaper-set.sh": 'printf "%s\\n" "$1" > /work/set-wallpaper',
            "artwork-fetch.sh": '''[[ -n "$1$2$4" ]] || exit 1
[[ "$2" != file:///work/artwork-race ]] || sleep 0.65
source=/work/image.svg
[[ "$1" != file:///work/tiny.svg ]] || source=/work/tiny.svg
mkdir -p "$(dirname "$5")"
duplicate=0
[[ ! -f "$6" ]] || ! cmp -s "$source" "$6" || duplicate=1
cp "$source" "$5"
[[ "$duplicate" == 0 ]] || exit 2''',
            "lyrics-fetch.sh": '''if [[ "$2" == Missing ]]; then
  printf '{"duration":0,"syncedLyrics":"","plainLyrics":""}\\n'
elif [[ "$2" == Retry && ! -e /work/retried ]]; then
  touch /work/retried
  printf '{"duration":0,"syncedLyrics":"","plainLyrics":"","retryable":true}\\n'
else
  [[ "$2" != Slow ]] || sleep 2
  sed "s/one/$2 one/" /work/lyrics.jsonl
fi''',
        }
        for name, body in mocks.items():
            script = scripts / name
            script.write_text('#!/usr/bin/env bash\n' + body + '\n')
            script.chmod(0o755)
        if progressive_wallpapers:
            (scripts / "wallpaper-list.sh").write_text('''#!/usr/bin/env bash
set -euo pipefail
if [[ "${2:-}" == --cached ]]; then
  printf '/work/first.mp4\\t\\t\\n/work/second.mp4\\t\\t\\n'
else
  sleep 0.5
  printf '/work/first.mp4\\t/work/first.jpg\\t/work/first.gif\\n'
  sleep 0.5
  printf '/work/second.mp4\\t/work/second.jpg\\t/work/second.gif\\n'
fi
''')
        if real_artwork:
            for name in ("artwork-fetch.sh", "media-match.jq", "media-cache.py"):
                shutil.copy2(REPO / "Configs/config/.config/hypr/scripts" / name, scripts / name)
        if real_wallpapers:
            (scripts / "wallpaper-set.sh").write_text('''#!/usr/bin/env bash
set -euo pipefail
sleep 0.3
printf '%s\\n' "$1" >> /work/wallpaper-selections
''')
            shutil.copy2(REPO / "Configs/config/.config/hypr/scripts/wallpaper-list.sh", scripts / "wallpaper-list-real.sh")
            (scripts / "wallpaper-list.sh").write_text('''#!/usr/bin/env bash
set -euo pipefail
listing="$(bash "$HOME/.config/hypr/scripts/wallpaper-list-real.sh" "$@")"
if [[ -e /work/slow-wallpaper-scan ]]; then
  touch /work/wallpaper-scan-started
  sleep 0.5
fi
printf '%s\\n' "$listing"
''')
            walls = desktop.work / "walls"
            walls.mkdir()
            (walls / "first.png").write_text("first wallpaper")
            (walls / "second.JPG").write_text("second wallpaper")
            (desktop.home / "walls").symlink_to("/work/walls")
        (desktop.work / "image.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600"><rect width="600" height="600" fill="#ab3456"/></svg>')
        (desktop.work / "corrected.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600"><rect width="600" height="600" fill="#56ab34"/></svg>')
        (desktop.work / "tiny.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60"><rect width="60" height="60" fill="#3456ab"/></svg>')
        (desktop.work / "wallpapers.tsv").write_text('/work/image.svg\t/work/image.svg\n/work/video.mp4\t/work/image.svg\t/work/preview.gif\n/work/image.svg\tignored\n')
        (desktop.work / "lyrics.jsonl").write_text('{"duration":180,"syncedLyrics":"[00:01.000]one\\n[00:02.000]two","plainLyrics":""}\n')
        (desktop.work / "reload-marker").write_text("")
        (desktop.work / "colors.json").write_text('{"accent":"#cba6f7"}\n')
        shutil.copy2(REPO / "tests/qml/FakePlayer.qml", desktop.work / "FakePlayer.qml")
        if real_artwork:
            fixture = desktop.work / "FakePlayer.qml"
            fixture.write_text(fixture.read_text().replace('"mpris:trackid": "A"', '"mpris:artUrl": "file:///work/image.svg", "mpris:trackid": "A"'))
        (desktop.work / "shell.qml").write_bytes(scenario.read_bytes())
        environment = {
            "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software", "PANEL_INITIAL_PLAYER": "1" if initial_player else "0",
            "PANEL_REAL_ARTWORK": "1" if real_artwork else "0",
            "QML_IMPORT_PATH": "/run/current-system/sw/lib/qt-6/qml",
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=/tmp/no-bus", "XDG_RUNTIME_DIR": "/tmp/runtime", "LANG": "C.UTF-8",
        }
        if with_fonts:
            (desktop.work / "fonts.conf").write_text(
                '<fontconfig><dir>/work/moxi/fonts</dir>'
                '<match target="font">'
                '<edit name="antialias" mode="assign"><bool>true</bool></edit>'
                '<edit name="hintstyle" mode="assign"><const>hintslight</const></edit>'
                '</match></fontconfig>'
            )
            environment["FONTCONFIG_FILE"] = "/work/fonts.conf"
            shell = desktop.work / "shell.qml"
            label = block_after(
                (source / "bar/Bar.qml").read_text(), "component SongLabel: RowLayout {"
            )
            shell.write_text(
                shell.read_text().replace(
                    "// SONG_LABEL_COMPONENT",
                    "component SongLabel: RowLayout {" + label + "}",
                )
            )
        command = "exec quickshell -p /work/shell.qml --no-color\n"
        if renderer == "opengl":
            environment.update({
                "QT_QPA_PLATFORM": "xcb", "QT_QUICK_BACKEND": "", "QSG_RHI_BACKEND": "opengl",
                "LIBGL_ALWAYS_SOFTWARE": "1", "DISPLAY": ":99", "QSG_INFO": "1",
                "LIBGL_DRIVERS_PATH": str(Path("/run/opengl-driver/lib/dri").resolve()),
                "LD_LIBRARY_PATH": str(Path("/run/opengl-driver/lib").resolve()),
            })
            command = '''Xvfb :99 -screen 0 1000x600x24 -nolisten tcp >/work/xvfb.log 2>&1 &
server=$!
trap 'kill "$server"; wait "$server"' EXIT
for attempt in {1..100}; do
  [[ -S /tmp/.X11-unix/X99 ]] && break
  sleep 0.02
done
quickshell -p /work/shell.qml --no-color
'''
        (desktop.work / "run.sh").write_text(deployment + command)
        result = desktop.run("/work/run.sh", **environment)
        output = result.stdout + result.stderr
        if renderer == "opengl":
            self.assertIn("OpenGL", output)
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("PANEL_SCENARIO_OK", output)
        for problem in ("ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Failed to load", "is not defined", "Unable to assign", "no signal of the target", "Cannot anchor", "PANEL_SCENARIO_FAILED"):
            self.assertNotIn(problem, output)

        return {path.name: path.read_bytes() for path in desktop.work.glob("panel-*.png")}
