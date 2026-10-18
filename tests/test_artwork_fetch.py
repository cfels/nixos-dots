import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

from support import IsolatedDesktop, REPO


FETCH = "/work/repo/Configs/config/.config/hypr/scripts/artwork-fetch.sh"


@unittest.skipUnless(shutil.which("magick"), "ImageMagick is required for image validation")
class ArtworkFetchTests(unittest.TestCase):
    def setUp(self):
        self.desktop = IsolatedDesktop()
        self.addCleanup(self.desktop.close)
        scripts = self.desktop.repo / "Configs/config/.config/hypr/scripts"
        scripts.mkdir(parents=True)
        for name in ("artwork-fetch.sh", "media-match.jq", "media-cache.py"):
            shutil.copy2(REPO / "Configs/config/.config/hypr/scripts" / name, scripts / name)
        for color in ("red", "blue"):
            subprocess.run(["magick", "-size", "600x600" if color == "blue" else "60x60", "xc:" + color, str(self.desktop.work / (color + ".png"))], check=True, capture_output=True)
        self.routes = {}
        curl = self.desktop.work / "bin/curl"
        curl.write_text(f"#!{sys.executable}\n" + '''
import json
from pathlib import Path
import sys

args = sys.argv[1:]
url = next((arg for arg in reversed(args) if arg.startswith(("https://", "http://"))), "")
with open("/work/requests.jsonl", "a") as log:
    log.write(json.dumps(url) + "\\n")
response = json.loads(Path("/work/artwork-routes.json").read_text()).get(url)
if response is None:
    sys.exit(22)
body = Path(response["file"]).read_bytes() if "file" in response else json.dumps(response.get("json", {})).encode()
if "-o" in args:
    Path(args[args.index("-o") + 1]).write_bytes(body)
else:
    sys.stdout.buffer.write(body)
''')
        curl.chmod(0o755)

    def fetch(self, art="", track="", artist="Artist", title="Song", current=""):
        (self.desktop.work / "artwork-routes.json").write_text(json.dumps(self.routes))
        return self.desktop.run(FETCH, art, track, artist, title, "/home/audituser/.cache/moxi/art/art-test.img", current, "Album")

    def requests(self):
        path = self.desktop.work / "requests.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def cached(self):
        return self.desktop.home / ".cache/moxi/art/art-test.img"

    def test_player_cover_precedes_search_and_youtube_thumbnail(self):
        self.routes["https://fixture.invalid/player"] = {"file": "/work/blue.png"}
        result = self.fetch("https://fixture.invalid/player", "https://youtube.com/watch?v=abcdefghijk")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.requests(), ["https://fixture.invalid/player"])
        self.assertEqual(self.cached().read_bytes(), (self.desktop.work / "blue.png").read_bytes())

    def test_local_cover_uri_decodes_spaces_and_unicode(self):
        shutil.copy2(self.desktop.work / "blue.png", self.desktop.work / "cover 世界.png")
        result = self.fetch("file:///work/cover%20%E4%B8%96%E7%95%8C.png")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.requests())
        self.assertEqual(self.cached().read_bytes(), (self.desktop.work / "blue.png").read_bytes())

    def test_localhost_file_uri_is_accepted(self):
        self.assertEqual(self.fetch("file://localhost/work/blue.png").returncode, 0)

    def test_remote_file_uri_is_rejected(self):
        result = self.fetch("file://other-host/work/blue.png", artist="", title="")
        self.assertEqual(result.returncode, 1)
        self.assertFalse(self.cached().exists())

    def test_wrong_search_results_are_rejected(self):
        self.routes["https://itunes.apple.com/search"] = {"json": {"results": [
            {"trackName": "Other Song", "artistName": "Artist", "artworkUrl100": "https://fixture.invalid/wrong"},
            {"trackName": "Song", "artistName": "Other Artist", "artworkUrl100": "https://fixture.invalid/wrong"},
        ]}}
        result = self.fetch()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.requests(), ["https://itunes.apple.com/search"])
        self.assertFalse(self.cached().exists())

    def test_matching_cover_is_selected_after_unrelated_result(self):
        self.routes["https://itunes.apple.com/search"] = {"json": {"results": [
            {"trackName": "Other Song", "artistName": "Artist", "artworkUrl100": "https://fixture.invalid/wrong"},
            {"trackName": "Song", "artistName": "Artist", "collectionName": "Album", "artworkUrl100": "https://fixture.invalid/100x100bb.jpg"},
        ]}}
        self.routes["https://fixture.invalid/1200x1200bb.jpg"] = {"file": "/work/blue.png"}
        result = self.fetch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("https://fixture.invalid/wrong", self.requests())
        self.assertEqual(self.cached().read_bytes(), (self.desktop.work / "blue.png").read_bytes())

    def test_japanese_character_credits_match_search_performers(self):
        self.routes["https://itunes.apple.com/search"] = {"json": {"results": [
            {"trackName": "動く、動く", "artistName": "水瀬いのり & 久保ユリカ", "artworkUrl100": "https://fixture.invalid/blue"},
        ]}}
        self.routes["https://fixture.invalid/blue"] = {"file": "/work/blue.png"}
        result = self.fetch(artist="チト（CV：水瀬いのり）、ユーリ（CV：久保ユリカ）", title="動く、動く")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_html_and_truncated_images_are_rejected_without_cache(self):
        for name, body in (("error.html", b"<html>temporary server error</html>"), ("broken.png", b"\x89PNG\r\n\x1a\n")):
            with self.subTest(name=name):
                (self.desktop.work / name).write_bytes(body)
                self.routes["https://fixture.invalid/bad"] = {"file": "/work/" + name}
                result = self.fetch("https://fixture.invalid/bad", artist="", title="")
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertFalse(self.cached().exists())
                self.assertFalse(list(self.cached().parent.glob("*.part.*")))

    def test_invalid_player_image_falls_back_to_valid_youtube_thumbnail(self):
        (self.desktop.work / "error.html").write_text("<html>error</html>")
        self.routes["https://fixture.invalid/bad"] = {"file": "/work/error.html"}
        self.routes["https://img.youtube.com/vi/abcdefghijk/maxresdefault.jpg"] = {"file": "/work/blue.png"}
        result = self.fetch("https://fixture.invalid/bad", "https://youtube.com/watch?v=abcdefghijk")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.cached().read_bytes(), (self.desktop.work / "blue.png").read_bytes())

    def test_invalid_existing_cache_is_replaced(self):
        self.cached().parent.mkdir(parents=True)
        self.cached().write_text("<html>old error</html>")
        self.assertEqual(self.fetch("file:///work/blue.png").returncode, 0)
        self.assertEqual(self.cached().read_bytes(), (self.desktop.work / "blue.png").read_bytes())

    def test_valid_cache_avoids_network_requests(self):
        self.assertEqual(self.fetch("file:///work/blue.png").returncode, 0)
        result = self.fetch("https://fixture.invalid/unavailable")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.requests())

    def test_duplicate_cover_is_cached_without_republishing(self):
        result = self.fetch("file:///work/blue.png", current="/work/blue.png")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertTrue(self.cached().is_file())

    def test_small_player_cover_is_upgraded_from_the_same_video(self):
        self.routes["https://img.youtube.com/vi/abcdefghijk/maxresdefault.jpg"] = {"file": "/work/blue.png"}
        result = self.fetch("file:///work/red.png", "https://youtube.com/watch?v=abcdefghijk")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.cached().read_bytes(), (self.desktop.work / "blue.png").read_bytes())

    def test_small_existing_cache_is_upgraded(self):
        self.cached().parent.mkdir(parents=True)
        shutil.copy2(self.desktop.work / "red.png", self.cached())
        self.routes["https://img.youtube.com/vi/abcdefghijk/maxresdefault.jpg"] = {"file": "/work/blue.png"}
        result = self.fetch("file:///work/red.png", "https://youtube.com/watch?v=abcdefghijk")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.cached().read_bytes(), (self.desktop.work / "blue.png").read_bytes())

    def test_late_thumbnail_cannot_replace_a_cached_high_resolution_cover(self):
        self.assertEqual(self.fetch("file:///work/blue.png").returncode, 0)
        result = self.fetch("file:///work/red.png")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.cached().read_bytes(), (self.desktop.work / "blue.png").read_bytes())

    def test_small_cover_remains_a_fallback_when_upgrades_fail(self):
        result = self.fetch("file:///work/red.png", "https://youtube.com/watch?v=abcdefghijk")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.cached().read_bytes(), (self.desktop.work / "red.png").read_bytes())
