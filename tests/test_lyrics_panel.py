import json
import shutil
import subprocess
import unittest

from support import REPO


LYRICS = REPO / "Configs/config/.config/quickshell/moxi/panel/LyricsController.qml"


def block_after(source, marker):
    start = source.index("{", source.index(marker))
    depth = 1
    end = start + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start + 1:end - 1]


@unittest.skipUnless(shutil.which("node"), "Node.js is required for extracted panel JavaScript checks")
class LyricsPanelTests(unittest.TestCase):
    def run_panel(self, checks):
        source = LYRICS.read_text()
        bodies = {name: block_after(source, "function " + name + "(") for name in ("applyLyrics", "fetchLyrics", "parseLyrics")}
        process = source[source.index("id: lyricsFetch"):]
        bodies["restartFetch"] = block_after(process, "onRunningChanged:")
        script = '''
const assert = require("node:assert/strict");
const bodies = JSON.parse(require("node:fs").readFileSync(0, "utf8"));
globalThis.panel = {
  trackTitle: "Song", trackDuration: 180, lyricsKey: "A", lyricsFetchKey: "",
  lyricsLoadedKey: "", lyrics: [], lyricsPlain: [], lyricsUnavailable: false,
  lyricsWanted: false, lookupDuration: 0, syncedLyrics: false, showLyrics: false,
  rememberDuration(value) { this.remembered = value; },
  noteMissingLyrics() { this.missing = true; },
  updateActiveLyric() {},
  applyPlainLyrics() { this.appliedPlain = true; }
};
globalThis.lyricsState = panel;
panel.media = panel;
globalThis.lyricsFetch = { running: false };
panel.applyLyrics = new Function("payload", bodies.applyLyrics);
panel.fetchLyrics = new Function(bodies.fetchLyrics);
panel.parseLyrics = new Function("raw", bodies.parseLyrics);
const restartFetch = new Function(bodies.restartFetch);
''' + checks
        result = subprocess.run(["node", "-e", script], input=json.dumps(bodies), capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rapid_track_changes_cancel_and_reject_stale_payloads(self):
        self.run_panel('''
panel.fetchLyrics();
assert.equal(lyricsFetch.running, true);
assert.equal(panel.lyricsFetchKey, "A");
panel.lyricsKey = "B";
panel.fetchLyrics();
assert.equal(lyricsFetch.running, false);
assert.equal(panel.lyricsWanted, true);
panel.applyLyrics(JSON.stringify({ duration: 999, syncedLyrics: "[00:01]stale", plainLyrics: "stale" }));
assert.deepEqual(panel.lyrics, []);
assert.equal(panel.lookupDuration, 0);
panel.lyricsKey = "C";
globalThis.running = false;
restartFetch();
assert.equal(panel.lyricsFetchKey, "C");
assert.equal(lyricsFetch.running, true);
panel.applyLyrics(JSON.stringify({ duration: 180, syncedLyrics: "[00:01.000]new one\\n[00:02.000]new two", plainLyrics: "" }));
assert.equal(panel.lyricsLoadedKey, "C");
assert.deepEqual(panel.lyrics, [{ time: 1, text: "new one" }, { time: 2, text: "new two" }]);
''')

    def test_duration_only_line_preserves_loaded_lyrics(self):
        self.run_panel('''
panel.lyricsFetchKey = panel.lyricsKey;
panel.lyricsLoadedKey = panel.lyricsKey;
panel.lyrics = [{ time: 1, text: "loaded" }];
panel.applyLyrics(JSON.stringify({ duration: 180, syncedLyrics: "", plainLyrics: "" }));
assert.equal(panel.lookupDuration, 180);
assert.equal(panel.remembered, 180);
assert.deepEqual(panel.lyrics, [{ time: 1, text: "loaded" }]);
assert.equal(panel.missing, undefined);
panel.applyLyrics("{malformed");
assert.deepEqual(panel.lyrics, [{ time: 1, text: "loaded" }]);
''')
