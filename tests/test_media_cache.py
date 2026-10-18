import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from support import REPO


spec = importlib.util.spec_from_file_location("media_cache", REPO / "Configs/config/.config/hypr/scripts/media-cache.py")
media_cache = importlib.util.module_from_spec(spec)
spec.loader.exec_module(media_cache)


class MediaCacheTests(unittest.TestCase):
    def test_cache_budget_is_150_mib(self):
        self.assertEqual(media_cache.MAX_CACHE_BYTES, 150 * 1024 * 1024)

    def test_combined_budget_evicts_the_least_recently_used_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lyrics = root / "lyrics/v1"
            artwork = root / "art"
            lyrics.mkdir(parents=True)
            artwork.mkdir()
            old_lyrics = lyrics / "old.json"
            old_artwork = artwork / "art-old.img"
            recent_lyrics = lyrics / "recent.json"
            recent_artwork = artwork / "art-recent.img"
            for index, path in enumerate((old_lyrics, old_artwork, recent_lyrics, recent_artwork)):
                path.write_bytes(b"x" * 300)
                os.utime(path, (index + 1,) * 2)
            with patch.object(media_cache, "MAX_CACHE_BYTES", 700):
                media_cache.prune(root)
            self.assertFalse(old_lyrics.exists())
            self.assertFalse(old_artwork.exists())
            self.assertTrue(recent_lyrics.exists())
            self.assertTrue(recent_artwork.exists())
            self.assertLessEqual(sum(path.stat().st_size for path in root.rglob("*") if path.is_file()), 700)

    def test_cache_within_budget_keeps_old_lyrics_and_unrelated_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lyrics = root / "lyrics/v1"
            lyrics.mkdir(parents=True)
            old = lyrics / "old.json"
            old.write_text("remembered lyrics")
            os.utime(old, (1, 1))
            unrelated = root / "unrelated.bin"
            unrelated.write_bytes(b"x" * 1000)
            with patch.object(media_cache, "MAX_CACHE_BYTES", 100):
                media_cache.prune(root)
            self.assertTrue(old.exists())
            self.assertTrue(unrelated.exists())
