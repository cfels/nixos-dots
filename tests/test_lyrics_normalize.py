import importlib.util
import json
import subprocess
import unittest

from support import REPO


NORMALIZER = REPO / "Configs/config/.config/hypr/scripts/lyrics-normalize.py"
spec = importlib.util.spec_from_file_location("lyrics_normalize", NORMALIZER)
normalizer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(normalizer)


class LyricsNormalizerTests(unittest.TestCase):
    def normalize(self, payload, duration=180, raw=False):
        result = subprocess.run(
            ["python3", "-B", str(NORMALIZER), str(duration)],
            input=payload if raw else json.dumps(payload, ensure_ascii=False),
            capture_output=True, text=True, timeout=5,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_timestamp_units_and_invalid_values(self):
        for value, expected in (("1000ms", 1), ("2s", 2), ("1.5m", 90), ("1h", 3600), ("01:02:03.5", 3723.5), (None, None), (True, None), ("nan", None), ("inf", None), (-1, None), ("bad", None)):
            with self.subTest(value=value):
                self.assertEqual(normalizer.seconds(value), expected)

    def test_lrc_timestamps_offsets_and_unicode(self):
        result = self.normalize("[offset:100]\n[00:01.20][00:02:50]Zażółć 世界\n[00:04.000]<00:04.100>다음", raw=True)
        self.assertEqual(result, {
            "duration": 0,
            "syncedLyrics": "[00:01.100]Zażółć 世界\n[00:02.400]Zażółć 世界\n[00:03.900]다음",
            "plainLyrics": "Zażółć 世界\nZażółć 世界\n다음",
        })

    def test_negative_offset_delays_lyrics(self):
        result = self.normalize("[offset:-200]\n[00:01.000]one\n[00:02.000]two", raw=True)
        self.assertEqual(result["syncedLyrics"], "[00:01.200]one\n[00:02.200]two")

    def test_ttml_ignores_translations_and_background_vocals(self):
        payload = '<tt xmlns:ttm="urn:metadata"><body><p begin="1000ms">One<span ttm:role="x-translation">Other</span><br/>line</p><p><span begin="2s">Two</span><span ttm:role="x-bg">Background</span></p></body></tt>'
        result = self.normalize(payload, raw=True)
        self.assertEqual(result["syncedLyrics"], "[00:01.000]One line\n[00:02.000]Two")

    def test_qrc_xml_preserves_attribute_newlines(self):
        payload = '<Qrc><Lyric LyricContent="[1000,500]One(1000,500)\n[2000,500]Two(2000,500)"/></Qrc>'
        result = self.normalize(payload, raw=True)
        self.assertEqual(result["syncedLyrics"], "[00:01.000]One\n[00:02.000]Two")

    def test_amll_romanization_does_not_duplicate_main_lyrics(self):
        payload = '<tt xmlns:ttm="urn:metadata"><body><p begin="1s">一<span ttm:role="x-roman">ichi</span></p><p begin="2s">二<span ttm:role="x-roman">ni</span></p></body></tt>'
        result = self.normalize(payload, raw=True)
        self.assertEqual(result["syncedLyrics"], "[00:01.000]一\n[00:02.000]二")
        self.assertEqual(result["plainLyrics"], "一\n二")

    def test_timed_json_supports_milliseconds_and_seconds(self):
        for key, values in (("time", (1000, 2000)), ("timestamp", (1000, 2000)), ("startTimeMs", (1000, 2000)), ("startTime", (1, 2))):
            with self.subTest(key=key):
                result = self.normalize({"lines": [{key: values[0], "text": "one"}, {key: values[1], "words": "two"}]})
                self.assertEqual(result["syncedLyrics"], "[00:01.000]one\n[00:02.000]two")

    def test_word_rows_and_syllables(self):
        result = self.normalize({"lines": [
            {"time": 1000, "words": [{"text": "one"}, {"text": "line"}]},
            {"time": 2000, "syllabus": [{"text": "二"}, {"text": "背景", "isBackground": True}]},
        ]})
        self.assertEqual(result["syncedLyrics"], "[00:01.000]one line\n[00:02.000]二")

    def test_plain_rows_are_not_promoted_to_synced(self):
        result = self.normalize({"type": "plain", "lines": [{"time": 1000, "text": "one"}, {"time": 2000, "text": "two"}]})
        self.assertEqual(result["syncedLyrics"], "")
        self.assertEqual(result["plainLyrics"], "one\ntwo")

    def test_explicit_plain_lyrics_and_metadata_are_preserved(self):
        result = self.normalize({"title": "曲", "artist": "歌手", "album": "盤", "duration": 20, "plainLyrics": "Don't\nchange me"})
        self.assertEqual(result, {"duration": 20, "syncedLyrics": "", "plainLyrics": "Don't\nchange me", "title": "曲", "artist": "歌手", "album": "盤"})

    def test_out_of_range_and_single_timestamp_keep_plain_fallback(self):
        for raw, plain in (("[00:01.000]one", "one"), ("[00:01.000]one\n[00:20.000]two", "one\ntwo")):
            with self.subTest(raw=raw):
                result = self.normalize(raw, duration=10, raw=True)
                self.assertEqual(result["syncedLyrics"], "")
                self.assertEqual(result["plainLyrics"], plain)

    def test_malformed_and_error_payloads_return_empty_contract(self):
        payloads = ["", "{bad", "<tt><p>", "unwrapped plain text", "null", "[]", '{"error":"failure"}', '{"success":false}', '{"ok":false}', '{"type":"failed"}']
        for payload in payloads:
            with self.subTest(payload=payload):
                self.assertEqual(self.normalize(payload, raw=True), {"duration": 0, "syncedLyrics": "", "plainLyrics": ""})

    def test_nested_json_strings_and_missing_metadata(self):
        lyric = "[00:01.000]one\n[00:02.000]two"
        result = self.normalize({"response": json.dumps({"data": {"lrc": lyric}})})
        self.assertEqual(result["syncedLyrics"], lyric)
        self.assertEqual(set(result), {"duration", "syncedLyrics", "plainLyrics"})
