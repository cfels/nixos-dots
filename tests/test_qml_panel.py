from pathlib import Path
import os
import re
import shutil
import unittest

from support import IsolatedDesktop, REPO


class QmlPanelTests(unittest.TestCase):
    def test_panel_runtime(self):
        self.run_scenario(REPO / "tests/qml/PanelScenario.qml")

    def test_stowed_layout(self):
        self.run_scenario(REPO / "tests/qml/PanelScenario.qml", installed_layout=True)

    def test_existing_player_on_load(self):
        self.run_scenario(REPO / "tests/qml/PanelScenario.qml", initial_player=True)

    def test_panel_with_real_artwork_fetcher(self):
        self.run_scenario(REPO / "tests/qml/PanelScenario.qml", real_artwork=True)

    def test_artwork_refresh_does_not_reanimate(self):
        self.run_scenario(REPO / "tests/qml/ArtworkScenario.qml")

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

    def run_scenario(self, scenario, source=None, renderer="software", initial_player=False, installed_layout=False, real_artwork=False):
        desktop = IsolatedDesktop()
        self.addCleanup(desktop.close)
        source = source or REPO / "Configs/config/.config/quickshell/moxi"
        target = desktop.work / "moxi"
        shutil.copytree(source, target)
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
        }
        text = text.replace("\tid: panel\n", "\tid: panel\n" + ''.join(f'\tproperty alias {key}: {value}\n' for key, value in aliases.items()), 1)
        lyrics_view = target / "panel/LyricsView.qml"
        if lyrics_view.exists():
            lyrics_view.write_text(lyrics_view.read_text().replace("id: lyricsDisplay\n", "id: lyricsDisplay\n\tproperty alias testList: lyricsView\n", 1))
        player_view = target / "panel/PlayerView.qml"
        if player_view.exists():
            player_view.write_text(player_view.read_text().replace("id: playerView\n", "id: playerView\n\tproperty alias testTimeline: progressTrack\n\tproperty alias testLyricsView: lyricsView.testList\n\tproperty alias testArtworkView: artwork\n", 1).replace("id: progressTrack\n", "id: progressTrack\n\t\tproperty alias testSweep: progressFill.sweep\n", 1))
            artwork_view = target / "panel/ArtworkView.qml"
            artwork_view.write_text(artwork_view.read_text().replace("id: artwork\n", "id: artwork\n\tproperty int testTransitions: 0\n", 1).replace("id: artSwap\n", "id: artSwap\n\t\tonStarted: artwork.testTransitions += 1\n", 1))
        else:
            text = text.replace("playerView.testTimeline", "progressTrack").replace("playerView.testLyricsView", "lyricsView")
        panel.write_text(text)
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
        if real_artwork:
            for name in ("artwork-fetch.sh", "media-match.jq", "media-cache.py"):
                shutil.copy2(REPO / "Configs/config/.config/hypr/scripts" / name, scripts / name)
        (desktop.work / "image.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600"><rect width="600" height="600" fill="#ab3456"/></svg>')
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
