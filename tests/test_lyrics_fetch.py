import json
import os
import signal
import shutil
import subprocess
import sys
import time
import unittest

from support import IsolatedDesktop, REPO


FETCH = "/work/repo/Configs/config/.config/hypr/scripts/lyrics-fetch.sh"
FIXTURES = REPO / "tests/fixtures/lyrics/providers.json"


class LyricsFetchTests(unittest.TestCase):
    def setUp(self):
        self.desktop = IsolatedDesktop()
        self.addCleanup(self.desktop.close)
        self.fixtures = json.loads(FIXTURES.read_text())
        directory = self.desktop.repo / "Configs/config/.config/hypr/scripts"
        directory.mkdir(parents=True)
        for name in ("lyrics-fetch.sh", "lyrics-normalize.py", "media-cache.py", "media-match.jq"):
            shutil.copy2(REPO / "Configs/config/.config/hypr/scripts" / name, directory / name)
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        curl = self.desktop.work / "bin/curl"
        curl.write_text(f"#!{sys.executable}\n" + '''
import json
import os
from pathlib import Path
import sys
import time

args = sys.argv[1:]
url = next((arg for arg in reversed(args) if arg.startswith(("https://", "http://"))), "")
route = url.split("?", 1)[0]
with open("/work/requests.jsonl", "a") as log:
    log.write(json.dumps({"route": route, "args": args}) + "\\n")
failures = json.loads(os.environ.get("CURL_FAILURES", "{}"))
if route in failures:
    print(json.loads(os.environ.get("CURL_HTTP_STATUS", "{}")).get(route, "404" if failures[route] == 22 else "000"), end="")
    sys.exit(failures[route])

def respond(body):
    if "-o" in args:
        Path(args[args.index("-o") + 1]).write_text(body)
        print("200", end="")
    else:
        print(body)

if route == os.environ.get("CURL_RAW_ROUTE"):
    respond(os.environ["CURL_RAW_RESPONSE"])
    sys.exit(0)
if os.environ.get("CURL_DELAY"):
    time.sleep(float(os.environ["CURL_DELAY"]))
duration_routes = {"https://itunes.apple.com/search", "https://api.deezer.com/search"}
if route in duration_routes and os.environ.get("DURATION_GATE"):
    deadline = time.monotonic() + 8
    output = Path("/work/lyrics-output")
    while not output.exists() or '"duration":0' not in output.read_text():
        if time.monotonic() >= deadline:
            sys.exit(28)
        time.sleep(0.01)
    if "itunes" in route:
        respond(json.dumps({"results": [{"trackName": "Fixture Song", "artistName": "Fixture Artist", "trackTimeMillis": 180000}]}))
    else:
        respond(json.dumps({"data": []}))
    sys.exit(0)
fixtures = json.loads(Path("/work/fixtures.json").read_text())
for provider in os.environ.get("LYRICS_PROVIDERS", "").split(","):
    responses = fixtures["providers"].get(provider, {}).get("responses", {})
    if route in responses:
        respond(json.dumps(responses[route], ensure_ascii=False))
        sys.exit(0)
sys.exit(22)
''')
        curl.chmod(0o755)

    def arguments(self, **metadata):
        value = {**self.fixtures["metadata"], **metadata}
        return [str(value[key]) for key in ("artist", "title", "album", "duration", "track")]

    def fetch(self, providers=(), **environment):
        environment.setdefault("LYRICS_CACHE", "0")
        result = self.desktop.run(
            FETCH, *self.arguments(), LYRICS_PROVIDERS=",".join(providers),
            APPLE_MUSIC_TOKEN="fixture-token", PAXSENIX_API_KEY="fixture-key", **environment,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return [json.loads(line) for line in result.stdout.splitlines()]

    def requests(self):
        return [json.loads(line) for line in (self.desktop.work / "requests.jsonl").read_text().splitlines()]

    def test_every_provider_route_matches_its_fixture(self):
        for name, fixture in self.fixtures["providers"].items():
            with self.subTest(provider=name):
                self.assertEqual(self.fetch([name]), [fixture["expected"]])

    def test_failed_first_provider_allows_another_provider(self):
        self.assertEqual(self.fetch(["netease"]), [self.fixtures["providers"]["netease"]["expected"]])
        routes = {request["route"] for request in self.requests()}
        self.assertIn("https://lrclib.net/api/get", routes)
        self.assertIn("https://music.163.com/api/song/lyric", routes)

    def test_equal_candidates_keep_existing_priority(self):
        result = self.fetch(["lrclib", "lrclib_search", "netease"])
        self.assertEqual(result, [self.fixtures["providers"]["lrclib"]["expected"]])

    def test_synced_candidate_wins_an_equal_score_plain_candidate(self):
        response = self.fixtures["providers"]["lrclib"]["responses"]["https://lrclib.net/api/get"]
        response["syncedLyrics"] = ""
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        self.assertEqual(self.fetch(["lrclib", "netease"]), [self.fixtures["providers"]["netease"]["expected"]])

    def test_synced_candidate_precedes_plain_candidate_with_better_album_match(self):
        response = self.fixtures["providers"]["lrclib"]["responses"]["https://lrclib.net/api/get"]
        response["syncedLyrics"] = ""
        response = self.fixtures["providers"]["netease"]["responses"]["https://music.163.com/api/search/get"]
        response["result"]["songs"][0]["album"]["name"] = "Another Edition"
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        self.assertEqual(self.fetch(["lrclib", "netease"]), [self.fixtures["providers"]["netease"]["expected"]])

    def test_japanese_character_credits_match_performers_and_search_by_their_names(self):
        self.fixtures["metadata"].update(title="動く、動く", artist="チト（CV：水瀬いのり）、ユーリ（CV：久保ユリカ）")
        response = self.fixtures["providers"]["netease"]["responses"]["https://music.163.com/api/search/get"]
        response["result"]["songs"][0].update(name="動く、動く", artists=[{"name": "水瀬いのり"}, {"name": "久保ユリカ"}])
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        self.assertEqual(self.fetch(["netease"]), [self.fixtures["providers"]["netease"]["expected"]])
        args = next(request["args"] for request in self.requests() if request["route"] == "https://music.163.com/api/search/get")
        self.assertIn("s=水瀬いのり 久保ユリカ 動く、動く", args)

    def test_japanese_character_credits_match_ascii_provider_credits(self):
        self.fixtures["metadata"].update(title="動く、動く", artist="チト（CV：水瀬いのり）、ユーリ（CV：久保ユリカ）")
        response = self.fixtures["providers"]["lyricsplus"]["responses"]["https://lyricsplus.binimum.org/v2/lyrics/get"]
        response.update(title="動く、動く", artist="チト(CV:水瀬いのり), ユーリ(CV:久保ユリカ)")
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        self.assertEqual(self.fetch(["lyricsplus"]), [self.fixtures["providers"]["lyricsplus"]["expected"]])

    def test_plain_lyrics_remain_usable(self):
        response = self.fixtures["providers"]["lrclib"]["responses"]["https://lrclib.net/api/get"]
        response["syncedLyrics"] = ""
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        result = self.fetch(["lrclib"])[0]
        self.assertEqual(result["syncedLyrics"], "")
        self.assertEqual(result["plainLyrics"], "lrclib one\nlrclib two")

    def test_wrong_song_is_rejected(self):
        response = self.fixtures["providers"]["lrclib"]["responses"]["https://lrclib.net/api/get"]
        response["trackName"] = "Another Song"
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        self.assertEqual(self.fetch(["lrclib"]), [{"duration": 180, "syncedLyrics": "", "plainLyrics": ""}])

    def test_missing_artist_metadata_is_rejected(self):
        response = self.fixtures["providers"]["lrclib"]["responses"]["https://lrclib.net/api/get"]
        del response["artistName"]
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        self.assertEqual(self.fetch(["lrclib"])[0]["syncedLyrics"], "")

    def test_duration_mismatch_is_rejected(self):
        response = self.fixtures["providers"]["lrclib"]["responses"]["https://lrclib.net/api/get"]
        response["duration"] = 190
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        self.assertEqual(self.fetch(["lrclib"])[0]["syncedLyrics"], "")

    def test_malformed_response_allows_fallback(self):
        result = self.fetch(["lrclib", "netease"], CURL_RAW_ROUTE="https://lrclib.net/api/get", CURL_RAW_RESPONSE="{malformed")
        self.assertEqual(result, [self.fixtures["providers"]["netease"]["expected"]])

    def test_unicode_metadata_is_passed_without_shell_interpretation(self):
        title = 'Zażółć 世界 "quoted" $(touch /work/injected)'
        artist = "歌手 & Artysta"
        response = self.fixtures["providers"]["lrclib"]["responses"]["https://lrclib.net/api/get"]
        response.update(trackName=title, artistName=artist)
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        result = self.desktop.run(FETCH, *self.arguments(title=title, artist=artist), LYRICS_PROVIDERS="lrclib")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["syncedLyrics"], self.fixtures["providers"]["lrclib"]["expected"]["syncedLyrics"])
        args = next(request["args"] for request in self.requests() if request["route"] == "https://lrclib.net/api/get")
        self.assertIn("track_name=" + title, args)
        self.assertIn("artist_name=" + artist, args)
        self.assertFalse((self.desktop.work / "injected").exists())

    def test_credential_gated_routes_are_not_called_without_credentials(self):
        result = self.desktop.run(FETCH, *self.arguments(), LYRICS_PROVIDERS="apple,paxsenix")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any("paxsenix.org" in request["route"] or "amp-api.music.apple.com" in request["route"] for request in self.requests()))

    def test_qq_referer_and_configured_network_timeout_are_preserved(self):
        self.fetch(["qq"], LYRICS_TIMEOUT="0.25")
        args = next(request["args"] for request in self.requests() if request["route"].endswith("fcg_query_lyric_new.fcg"))
        self.assertIn("Referer: https://y.qq.com/", args)
        self.assertEqual(args[args.index("--connect-timeout") + 1], "2")
        self.assertEqual(args[args.index("--max-time") + 1], "0.25")

    def test_custom_lyricsplus_endpoint_is_preserved(self):
        responses = self.fixtures["providers"]["lyricsplus"]["responses"]
        responses["https://fixture.invalid/v2/lyrics/get"] = responses.pop("https://lyricsplus.binimum.org/v2/lyrics/get")
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        self.assertEqual(self.fetch(["lyricsplus"], LYRICSPLUS_URL="https://fixture.invalid"), [self.fixtures["providers"]["lyricsplus"]["expected"]])

    def test_custom_lrcmux_endpoint_is_preserved(self):
        responses = self.fixtures["providers"]["lrcmux"]["responses"]
        responses["https://fixture.invalid/compat/lrclib/api/get"] = responses.pop("https://api.lrcmux.dev/compat/lrclib/api/get")
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        self.assertEqual(self.fetch(["lrcmux"], LRCMUX_URL="https://fixture.invalid"), [self.fixtures["providers"]["lrcmux"]["expected"]])

    def test_new_providers_reject_wrong_recordings(self):
        for provider in ("lrcmux", "amll"):
            for mismatch in ("title", "artist", "duration"):
                with self.subTest(provider=provider, mismatch=mismatch):
                    fixtures = json.loads(FIXTURES.read_text())
                    responses = fixtures["providers"][provider]["responses"]
                    if provider == "lrcmux":
                        record = responses["https://api.lrcmux.dev/compat/lrclib/api/get"]
                        key = {"title": "trackName", "artist": "artistName", "duration": "duration"}[mismatch]
                    else:
                        record = responses["https://music.163.com/api/search/get"]["result"]["songs"][0]
                        key = {"title": "name", "artist": "artists", "duration": "duration"}[mismatch]
                    record[key] = {"title": "Wrong Song", "artist": [{"name": "Wrong Artist"}] if provider == "amll" else "Wrong Artist", "duration": 195000 if provider == "amll" else 195}[mismatch]
                    (self.desktop.work / "fixtures.json").write_text(json.dumps(fixtures))
                    self.assertEqual(self.fetch([provider]), [{"duration": 180, "syncedLyrics": "", "plainLyrics": ""}])

    def test_amll_rejects_invalid_catalog_ids(self):
        response = self.fixtures["providers"]["amll"]["responses"]["https://music.163.com/api/search/get"]
        response["result"]["songs"][0]["id"] = "../../unexpected"
        (self.desktop.work / "fixtures.json").write_text(json.dumps(self.fixtures))
        self.assertEqual(self.fetch(["amll"]), [{"duration": 180, "syncedLyrics": "", "plainLyrics": ""}])
        self.assertFalse(any("raw.githubusercontent.com" in request["route"] for request in self.requests()))

    def test_new_providers_fall_back_after_network_failure(self):
        for provider, route in (("lrcmux", "https://api.lrcmux.dev/compat/lrclib/api/get"), ("amll", "https://raw.githubusercontent.com/amll-dev/amll-ttml-db/main/ncm-lyrics/101.ttml")):
            with self.subTest(provider=provider):
                result = self.fetch([provider, "lrclib"], CURL_FAILURES=json.dumps({route: 28}))
                self.assertEqual(result, [self.fixtures["providers"]["lrclib"]["expected"]])

    def test_timeout_and_network_error_allow_fallback(self):
        for status in (7, 28):
            with self.subTest(curl_status=status):
                result = self.fetch(["lrclib", "netease"], CURL_FAILURES=json.dumps({"https://lrclib.net/api/get": status}))
                self.assertEqual(result, [self.fixtures["providers"]["netease"]["expected"]])

    def test_empty_results_keep_the_output_contract(self):
        self.assertEqual(self.fetch(), [{"duration": 180, "syncedLyrics": "", "plainLyrics": ""}])

    def test_successful_primary_sources_skip_fallback_requests(self):
        self.fetch(["lrclib"])
        self.assertEqual({request["route"] for request in self.requests()}, {
            "https://lrclib.net/api/get", "https://lrclib.net/api/search", "https://music.163.com/api/search/get",
        })

    def test_cached_lyrics_survive_another_lookup_without_network(self):
        expected = self.fetch(["lrclib"], LYRICS_CACHE="1")
        before = len(self.requests())
        self.assertEqual(self.fetch(LYRICS_CACHE="1"), expected)
        self.assertEqual(len(self.requests()), before)

    def test_corrupted_cache_is_refetched(self):
        self.fetch(["lrclib"], LYRICS_CACHE="1")
        cache = next((self.desktop.home / ".cache/moxi/lyrics/v1").glob("*.json"))
        cache.write_text('{"duration":true,"syncedLyrics":[],"plainLyrics":null}')
        result = self.fetch(["netease"], LYRICS_CACHE="1")
        self.assertEqual(result, [self.fixtures["providers"]["netease"]["expected"]])

    def test_successful_lyrics_are_remembered_beyond_a_week(self):
        expected = self.fetch(["lrclib"], LYRICS_CACHE="1")
        cache = next((self.desktop.home / ".cache/moxi/lyrics/v1").glob("*.json"))
        os.utime(cache, (time.time() - 90 * 86400,) * 2)
        before = len(self.requests())
        self.assertEqual(self.fetch(LYRICS_CACHE="1"), expected)
        self.assertEqual(len(self.requests()), before)
        self.assertGreater(cache.stat().st_mtime, time.time() - 5)

    def test_duration_and_recording_are_part_of_cache_identity(self):
        self.fetch(["lrclib"], LYRICS_CACHE="1")
        before = len(self.requests())
        self.fixtures["metadata"]["duration"] = 181
        self.fetch(["netease"], LYRICS_CACHE="1")
        self.assertGreater(len(self.requests()), before)
        before = len(self.requests())
        self.fixtures["metadata"]["track"] = "https://www.youtube.com/watch?v=otherrecord"
        self.fetch(["netease"], LYRICS_CACHE="1")
        self.assertGreater(len(self.requests()), before)

    def test_transient_network_misses_are_retryable_and_not_cached(self):
        route = "https://lrclib.net/api/get"
        for status, http_status in ((7, "000"), (28, "000"), (22, "429"), (22, "503")):
            with self.subTest(status=status, http_status=http_status):
                result = self.fetch(LYRICS_CACHE="1", CURL_FAILURES=json.dumps({route: status}), CURL_HTTP_STATUS=json.dumps({route: http_status}))
                self.assertEqual(result, [{"duration": 180, "syncedLyrics": "", "plainLyrics": "", "retryable": True}])
                self.assertFalse(list((self.desktop.home / ".cache/moxi/lyrics/v1").glob("*.json")))
        self.assertEqual(self.fetch(["lrclib"], LYRICS_CACHE="1"), [self.fixtures["providers"]["lrclib"]["expected"]])

    def test_definitive_misses_have_a_short_lived_cache(self):
        expected = self.fetch(LYRICS_CACHE="1")
        before = len(self.requests())
        self.assertEqual(self.fetch(["lrclib"], LYRICS_CACHE="1"), expected)
        self.assertEqual(len(self.requests()), before)
        cache = next((self.desktop.home / ".cache/moxi/lyrics/v1").glob("*.json"))
        os.utime(cache, (time.time() - 901,) * 2)
        self.assertEqual(self.fetch(["lrclib"], LYRICS_CACHE="1"), [self.fixtures["providers"]["lrclib"]["expected"]])

    def test_small_cache_entries_are_not_evicted_by_an_entry_count_limit(self):
        cache = self.desktop.home / ".cache/moxi/lyrics/v1"
        cache.mkdir(parents=True)
        for index in range(260):
            (cache / (str(index) + ".json")).write_text("{}")
        self.fetch(["lrclib"], LYRICS_CACHE="1")
        self.assertEqual(len(list(cache.glob("*.json"))), 261)

    def test_local_lrc_precedes_network_search(self):
        (self.desktop.work / "song.lrc").write_text("[00:01.000]local one\n[00:02.000]local two\n")
        result = self.desktop.run(FETCH, *self.arguments(track="file:///work/song.mp3"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["syncedLyrics"], "[00:01.000]local one\n[00:02.000]local two")
        self.assertFalse((self.desktop.work / "requests.jsonl").exists())

    def test_missing_title_emits_no_output_or_requests(self):
        result = self.desktop.run(FETCH, *self.arguments(title=""))
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertFalse((self.desktop.work / "requests.jsonl").exists())

    def test_late_duration_is_a_second_json_line(self):
        wrapper = self.desktop.work / "fetch-with-output.sh"
        wrapper.write_text('set -o pipefail\nbash ' + FETCH + ' "$@" | tee /work/lyrics-output\n')
        result = self.desktop.run("/work/fetch-with-output.sh", *self.arguments(duration=0, track=""), DURATION_GATE="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([json.loads(line) for line in result.stdout.splitlines()], [
            {"duration": 0, "syncedLyrics": "", "plainLyrics": ""},
            {"duration": 180, "syncedLyrics": "", "plainLyrics": ""},
        ])

    def test_cancelled_process_group_cannot_publish_late_results(self):
        process = subprocess.Popen(
            self.desktop.command(FETCH, *self.arguments(), CURL_DELAY="5", LYRICS_PROVIDERS="lrclib"),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True,
        )
        try:
            deadline = time.monotonic() + 5
            while not (self.desktop.work / "requests.jsonl").exists() and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertTrue((self.desktop.work / "requests.jsonl").is_file())
            self.assertIsNone(process.poll())
            os.killpg(process.pid, signal.SIGTERM)
            stdout, _ = process.communicate(timeout=5)
            self.assertFalse(any(line.startswith('{"duration"') for line in stdout.splitlines()))
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate(timeout=5)
