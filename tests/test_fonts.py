import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from support import REPO

try:
    import uharfbuzz as hb
    from fontTools.ttLib import TTFont
    from fontTools.ttLib.sfnt import calcChecksum
except ImportError:
    hb = TTFont = calcChecksum = None


FONT_DIRECTORY = REPO / "Configs/config/.config/quickshell/moxi/fonts"
FILES = [
    "momotrust.ttf",
    "NotoSans-ExtraBold-RU.ttf",
    "NotoSansJP-ExtraBold.ttf",
    "NotoSansKR-ExtraBold.ttf",
]


@unittest.skipUnless(
    TTFont and hb, "Use scripts/fonts/shell.nix for fontTools and HarfBuzz"
)
class FontTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location(
            "moxi_font_build", REPO / "scripts/fonts/build.py"
        )
        cls.builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.builder)
        cls.sources = cls.enterClassContext(cls.builder.source_directory())
        cls.originals = [TTFont(cls.sources / name) for name in FILES]
        cls.merged = TTFont(
            FONT_DIRECTORY / "MoxiTrust-ExtraBold.ttf", checkChecksums=2
        )
        cls.report = json.loads(
            (FONT_DIRECTORY / "MoxiTrust-ExtraBold.json").read_text()
        )

    @classmethod
    def tearDownClass(cls):
        for font in [*cls.originals, cls.merged]:
            font.close()

    @staticmethod
    def shape(path, text, language, features=None):
        font = hb.Font(hb.Face(path.read_bytes()))
        buffer = hb.Buffer()
        buffer.add_str(text)
        buffer.guess_segment_properties()
        buffer.language = language
        hb.shape(font, buffer, features or {})
        return [
            (
                glyph.codepoint,
                value.x_advance,
                value.y_advance,
                value.x_offset,
                value.y_offset,
            )
            for glyph, value in zip(buffer.glyph_infos, buffer.glyph_positions)
        ]

    def test_all_source_codepoints_have_one_consistent_mapping(self):
        expected = set().union(*(font.getBestCmap() for font in self.originals))
        self.assertEqual(set(self.merged.getBestCmap()), expected)
        observed = {}
        for table in self.merged["cmap"].tables:
            if not table.isUnicode() or table.format == 14:
                continue
            for codepoint, glyph in table.cmap.items():
                self.assertNotEqual(self.merged.getGlyphID(glyph), 0, hex(codepoint))
                self.assertEqual(
                    observed.setdefault(codepoint, glyph), glyph, hex(codepoint)
                )
        for first, last in (
            (0x400, 0x4FF),
            (0x3041, 0x3096),
            (0x30A1, 0x30FA),
            (0x1100, 0x11FF),
            (0xAC00, 0xD7A3),
        ):
            self.assertTrue(set(range(first, last + 1)) <= expected)

    def test_every_original_momo_glyph_spacing_and_hint_is_unchanged(self):
        self.builder.validate_font(self.merged, self.originals)
        for codepoint, name in self.originals[0].getBestCmap().items():
            self.assertEqual(
                self.merged.getGlyphID(self.merged.getBestCmap()[codepoint]),
                self.originals[0].getGlyphID(name),
            )
        for tag in ("fpgm", "prep", "cvt "):
            self.assertEqual(
                self.merged.getTableData(tag), self.originals[0].getTableData(tag)
            )

    def test_latin_kerning_marks_and_features_match_momo(self):
        for text in (
            "AVATAR To Wa fi ffi",
            "a\u0301\u0323 A\u0306",
            "Momo Trust — 0123456789",
            "Tiếng Việt",
            "gaga roro",
        ):
            for features in ({}, {"ss01": True}):
                with self.subTest(text=text, features=features):
                    self.assertEqual(
                        self.shape(self.sources / FILES[0], text, "en", features),
                        self.shape(
                            FONT_DIRECTORY / "MoxiTrust-ExtraBold.ttf",
                            text,
                            "en",
                            features,
                        ),
                    )

    def test_multilingual_shaping_and_hangul_composition(self):
        path = FONT_DIRECTORY / "MoxiTrust-ExtraBold.ttf"
        for text, language in (
            ("私が私の事を愛して 可愛くてごめん", "ja"),
            ("シカ色デイズ", "ja"),
            ("한글 한국어 사랑해요", "ko"),
            ("ангелочек Привет, мир!", "ru"),
        ):
            shaped = self.shape(path, text, language)
            self.assertTrue(shaped)
            self.assertTrue(all(glyph[0] != 0 for glyph in shaped), text)
        self.assertEqual(self.shape(path, "한글", "ko"), self.shape(path, "한글", "ko"))

    def test_cyrillic_stress_uses_original_momo_mark_with_real_attachment(self):
        shaped = self.shape(FONT_DIRECTORY / "MoxiTrust-ExtraBold.ttf", "а\u0301", "ru")
        self.assertEqual(len(shaped), 2)
        mark = shaped[-1]
        original_mark = self.originals[0].getGlyphID(
            self.originals[0].getBestCmap()[0x301]
        )
        self.assertEqual(mark[0], original_mark)
        self.assertEqual(mark[1], 0)
        self.assertNotEqual(mark[3:], (0, 0))

    def test_korean_han_variants_are_language_specific(self):
        path = FONT_DIRECTORY / "MoxiTrust-ExtraBold.ttf"
        japanese = self.shape(path, "伴侵乳", "ja")
        korean = self.shape(path, "伴侵乳", "ko")
        self.assertNotEqual(
            [item[0] for item in japanese], [item[0] for item in korean]
        )
        self.assertEqual(japanese, self.shape(path, "伴侵乳", "ko", {"locl": False}))
        self.assertEqual(self.report["koreanHanAlternates"], 607)

    def test_weight_names_license_and_line_metrics(self):
        self.assertEqual(self.merged["name"].getBestFamilyName(), "Moxi Trust")
        self.assertEqual(self.merged["OS/2"].usWeightClass, 800)
        self.assertEqual(self.merged["head"].unitsPerEm, 1000)
        for attribute in ("ascent", "descent", "lineGap"):
            self.assertEqual(
                getattr(self.merged["hhea"], attribute),
                getattr(self.originals[0]["hhea"], attribute),
            )
        self.assertGreaterEqual(
            self.merged["OS/2"].usWinAscent, self.merged["head"].yMax
        )
        self.assertGreaterEqual(
            self.merged["OS/2"].usWinDescent, -self.merged["head"].yMin
        )
        notices = self.merged["name"].getDebugName(0)
        for source in self.originals:
            self.assertIn(source["name"].getDebugName(0), notices)
        self.assertIn("SIL Open Font License", self.merged["name"].getDebugName(13))
        self.assertIn(
            "Reserved Font Name 'Source'", (FONT_DIRECTORY / "OFL.txt").read_text()
        )

    def test_outputs_match_manifest_and_woff2_is_lossless(self):
        for name, expected in self.report["artifacts"].items():
            path = FONT_DIRECTORY / name
            self.assertEqual(path.stat().st_size, expected["bytes"])
            self.assertEqual(self.builder.digest(path), expected["sha256"])
        self.assertEqual(
            calcChecksum((FONT_DIRECTORY / "MoxiTrust-ExtraBold.ttf").read_bytes()),
            0xB1B0AFBA,
        )
        with TTFont(FONT_DIRECTORY / "MoxiTrust-ExtraBold.woff2") as compressed:
            self.assertEqual(compressed.getBestCmap(), self.merged.getBestCmap())
            self.builder.validate_font(compressed, self.originals)
        self.assertLess(
            (FONT_DIRECTORY / "MoxiTrust-ExtraBold.woff2").stat().st_size,
            (FONT_DIRECTORY / "MoxiTrust-ExtraBold.ttf").stat().st_size * 0.4,
        )

    def test_corner_rounding_leaves_short_strokes_and_existing_curves_safe(self):
        original = [(0, 0), (100, 0), (100, 100), (0, 100)]
        points, flags = self.builder.round_contour(original, [1] * 4, 9)
        self.assertEqual(len(points), 12)
        self.assertEqual(flags.count(0), 4)
        small = [(0, 0), (8, 0), (8, 8), (0, 8)]
        self.assertEqual(
            self.builder.round_contour(small, [1] * 4, 9), (small, [1] * 4)
        )

    def test_changed_inputs_are_rejected_before_generating_any_font(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / "momotrust.ttf").write_bytes(b"unexpected source")
            with self.assertRaisesRegex(ValueError, "checksum changed"):
                self.builder.build(directory, directory / "output")
            self.assertFalse((directory / "output").exists())

    def test_old_fonts_are_not_shipped_or_installed(self):
        for name in FILES:
            self.assertFalse((FONT_DIRECTORY / name).exists())
        installed = REPO / "Configs/local/.local/share/fonts"
        self.assertFalse((installed / "MomoTrust").exists())
        self.assertEqual(
            (installed / "MoxiTrust/MoxiTrust-ExtraBold.ttf").resolve(strict=True),
            FONT_DIRECTORY / "MoxiTrust-ExtraBold.ttf",
        )

    def test_missing_history_explains_how_to_supply_build_sources(self):
        with (
            patch.object(self.builder.subprocess, "run", side_effect=FileNotFoundError),
            self.assertRaisesRegex(RuntimeError, "use --sources PATH"),
            self.builder.source_directory(),
        ):
            self.fail("Unavailable source history was accepted")


if __name__ == "__main__":
    unittest.main()
