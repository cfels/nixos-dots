#!/usr/bin/env python3
"""Build Moxi Trust from the four pinned, OFL-licensed source fonts."""

import argparse
import copy
import hashlib
import json
import logging
import math
import os
import subprocess
import tempfile
import unicodedata
from array import array
from contextlib import contextmanager
from pathlib import Path

import fontTools
from fontTools import subset
from fontTools.merge import Merger, Options
from fontTools.misc.fixedTools import otRound
from fontTools.otlLib.builder import (
    buildLookup,
    buildMarkBasePosSubtable,
    buildSingleSubstSubtable,
)
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.tables import otTables
from fontTools.ttLib.tables._g_l_y_f import Glyph, GlyphCoordinates, flagOnCurve
from fontTools.ttLib.tables.ttProgram import Program
from fontTools.ttLib.ttVisitor import TTVisitor

ROOT = Path(__file__).resolve().parents[2]
FONT_DIRECTORY = ROOT / "Configs/config/.config/quickshell/moxi/fonts"
SOURCE_MANIFEST = Path(__file__).with_name("sources.json")
PROFILES = {
    "momotrust.ttf": (1.0, 1.0, 0, 0, 0),
    "NotoSans-ExtraBold-RU.ttf": (1.025, 1.05, -12, 0, 12),
    "NotoSansJP-ExtraBold.ttf": (0.94, 0.94, 0, 24, 9),
    "NotoSansKR-ExtraBold.ttf": (0.94, 0.94, 0, 24, 9),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


@contextmanager
def source_directory(directory=None):
    """Recover build inputs from Git without installing obsolete source fonts."""
    if directory is not None:
        yield directory
        return
    manifest = json.loads(SOURCE_MANIFEST.read_text())
    with tempfile.TemporaryDirectory(prefix="moxi-font-sources-") as temporary:
        directory = Path(temporary)
        for name, expected in manifest["sources"].items():
            revision_path = f"{manifest['revision']}:{manifest['directory']}/{name}"
            try:
                result = subprocess.run(
                    ["git", "-C", str(ROOT), "show", revision_path],
                    check=True,
                    capture_output=True,
                )
            except (OSError, subprocess.CalledProcessError) as error:
                raise RuntimeError(
                    f"Cannot recover font source {name} from Git revision {manifest['revision']}. "
                    "Restore that revision's Git history, or use --sources PATH with the original four TTFs."
                ) from error
            path = directory / name
            path.write_bytes(result.stdout)
            if digest(path) != expected:
                raise ValueError(f"Archived source checksum changed: {name}")
        yield directory


def is_han(codepoint):
    return (
        0x3400 <= codepoint <= 0x9FFF
        or 0xF900 <= codepoint <= 0xFAFF
        or 0x20000 <= codepoint <= 0x323AF
    )


def glyph_signature(font, name):
    coordinates, ends, flags = font["glyf"][name].getCoordinates(font["glyf"])
    return tuple(coordinates), tuple(ends), bytes(flags), font["hmtx"][name]


def round_contour(points, flags, radius):
    """Fillet line-line corners only; retain curves and limit cuts on short strokes."""
    result, result_flags = [], []
    count = len(points)
    for index, point in enumerate(points):
        previous, following = points[index - 1], points[(index + 1) % count]
        adjacent_on_curve = all(
            flags[i % count] & flagOnCurve for i in (index - 1, index, index + 1)
        )
        incoming = (previous[0] - point[0], previous[1] - point[1])
        outgoing = (following[0] - point[0], following[1] - point[1])
        first, second = math.hypot(*incoming), math.hypot(*outgoing)
        if not adjacent_on_curve or min(first, second) < 12:
            result.append(point)
            result_flags.append(flags[index])
            continue
        cosine = (incoming[0] * outgoing[0] + incoming[1] * outgoing[1]) / (
            first * second
        )
        if cosine > 0.85 or cosine < -0.98:
            result.append(point)
            result_flags.append(flags[index])
            continue
        trim = min(
            radius / math.tan(math.acos(max(-1, min(1, cosine))) / 2),
            first * 0.12,
            second * 0.12,
        )
        if trim < 1.5:
            result.append(point)
            result_flags.append(flags[index])
            continue
        before = (
            point[0] + incoming[0] / first * trim,
            point[1] + incoming[1] / first * trim,
        )
        after = (
            point[0] + outgoing[0] / second * trim,
            point[1] + outgoing[1] / second * trim,
        )
        result.extend((before, point, after))
        result_flags.extend((flagOnCurve, 0, flagOnCurve))
    return result, result_flags


class LayoutTransform(TTVisitor):
    def __init__(self, sx, sy, dx, dy):
        self.sx, self.sy, self.dx, self.dy = sx, sy, dx, dy

    def visitAttr(self, obj, attr, value, *args, **kwargs):
        if isinstance(value, int):
            if attr in ("XAdvance", "XPlacement"):
                setattr(obj, attr, otRound(value * self.sx))
            elif attr in ("YAdvance", "YPlacement"):
                setattr(obj, attr, otRound(value * self.sy))
            elif isinstance(obj, otTables.Anchor) and attr == "XCoordinate":
                obj.XCoordinate = otRound(value * self.sx + self.dx)
            elif isinstance(obj, otTables.Anchor) and attr == "YCoordinate":
                obj.YCoordinate = otRound(value * self.sy + self.dy)
            elif isinstance(obj, otTables.CaretValue) and attr == "Coordinate":
                obj.Coordinate = otRound(value * self.sx + self.dx)
        if isinstance(obj, otTables.Anchor) and getattr(obj, "Format", 0) == 2:
            # Point indices change when fillets are inserted. Explicit coordinates do not.
            obj.Format = 1
            del obj.AnchorPoint
        return super().visitAttr(obj, attr, value, *args, **kwargs)


class NameRemapper(TTVisitor):
    def __init__(self, names):
        self.names = names

    def visitAttr(self, obj, attr, value, *args, **kwargs):
        if (
            isinstance(value, int)
            and attr.endswith(("NameID", "NameId"))
            and value in self.names
        ):
            setattr(obj, attr, self.names[value])
        return super().visitAttr(obj, attr, value, *args, **kwargs)


def merge_feature_names(fonts):
    names = fonts[0]["name"]
    next_id = max(256, max(record.nameID for record in names.names) + 1)
    for font in fonts[1:]:
        identifiers = {
            record.nameID for record in font["name"].names if record.nameID >= 256
        }
        if not identifiers:
            continue
        # A run of parameter-label IDs must remain contiguous after remapping.
        mapping = {
            identifier: next_id + identifier - min(identifiers)
            for identifier in range(min(identifiers), max(identifiers) + 1)
        }
        next_id = max(mapping.values()) + 1
        for record in font["name"].names:
            if record.nameID in mapping:
                copied = copy.deepcopy(record)
                copied.nameID = mapping[record.nameID]
                names.names.append(copied)
        for tag in ("GSUB", "GPOS"):
            if tag in font:
                NameRemapper(mapping).visit(font[tag].table)


def adapt_outlines(font, profile):
    sx, sy, dx, dy, radius = profile
    table = font["glyf"]
    # Expand all composites before changing any referenced contours.
    outlines = {
        name: table[name].getCoordinates(table) for name in font.getGlyphOrder()
    }
    changed = 0
    for name, (coordinates, ends, flags) in outlines.items():
        scaled = [(x * sx + dx, y * sy + dy) for x, y in coordinates]
        points, new_flags, new_ends, start = [], [], [], 0
        for end in ends:
            contour, contour_flags = round_contour(
                scaled[start : end + 1], flags[start : end + 1], radius
            )
            points.extend(contour)
            new_flags.extend(contour_flags)
            new_ends.append(len(points) - 1)
            start = end + 1
        glyph = Glyph()
        glyph.numberOfContours = len(new_ends)
        glyph.program = Program()
        glyph.program.fromBytecode(b"")
        if points:
            glyph.coordinates = GlyphCoordinates(
                (otRound(x), otRound(y)) for x, y in points
            )
            glyph.endPtsOfContours = new_ends
            glyph.flags = array("B", new_flags)
        table[name] = glyph
        glyph.recalcBounds(table)
        advance, _ = font["hmtx"][name]
        width = max(1, otRound(advance * sx + 2 * dx)) if advance else 0
        font["hmtx"][name] = width, getattr(glyph, "xMin", 0)
        if "vmtx" in font:
            vertical, bearing = font["vmtx"][name]
            font["vmtx"][name] = otRound(vertical * sy), otRound(bearing * sy)
        changed += len(points) != len(coordinates)
    transform = LayoutTransform(sx, sy, dx, dy)
    for tag in ("GPOS", "GDEF"):
        if tag in font:
            transform.visit(font[tag].table)
    return changed


def trim_cmap(font, owned):
    for table in font["cmap"].tables:
        if table.isUnicode() and table.format != 14:
            table.cmap = {
                codepoint: name
                for codepoint, name in table.cmap.items()
                if codepoint in owned
            }


def regional_han(japanese, korean, protected):
    jp, kr = japanese.getBestCmap(), korean.getBestCmap()
    return {
        codepoint: kr[codepoint]
        for codepoint in sorted((jp.keys() & kr.keys()) - protected)
        if is_han(codepoint)
        and glyph_signature(japanese, jp[codepoint])
        != glyph_signature(korean, kr[codepoint])
    }


def prepare(font, owned, extra_glyphs):
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.glyph_names = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.hinting = False
    # Variation-selector glyphs must survive even if a shared base uses another source.
    variation_bases = set()
    for table in font["cmap"].tables:
        if table.format == 14:
            variation_bases.update(
                codepoint
                for mappings in table.uvsDict.values()
                for codepoint, _ in mappings
            )
    selection = subset.Subsetter(options=options)
    selection.populate(unicodes=owned | variation_bases, glyphs=extra_glyphs)
    selection.subset(font)
    trim_cmap(font, owned)
    for tag in ("STAT", "prep", "cvt ", "fpgm"):
        if tag in font:
            del font[tag]


def mark_subtables(font):
    if "GPOS" not in font:
        return
    for lookup in font["GPOS"].table.LookupList.Lookup:
        for subtable in lookup.SubTable:
            if lookup.LookupType == 9:
                subtable = subtable.ExtSubTable
            if isinstance(subtable, otTables.MarkBasePos):
                yield subtable


def bridge_marks(merged, fonts, glyph_maps):
    """Attach original Momo combining marks to added bases using source anchors."""
    canonical = {}
    cmap = fonts[0].getBestCmap()
    for table in mark_subtables(fonts[0]):
        for name, record in zip(table.MarkCoverage.glyphs, table.MarkArray.MarkRecord):
            canonical[name] = copy.deepcopy(record.MarkAnchor)
    added = 0
    gpos = merged["GPOS"].table
    for font, names in zip(fonts[1:], glyph_maps[1:]):
        reverse = {name: cp for cp, name in font.getBestCmap().items()}
        # The subset's cmap excludes duplicates; use the original source cmap saved before trimming.
        reverse.update(font._moxi_mark_codepoints)
        for table in mark_subtables(font):
            marks = {}
            for name, record in zip(
                table.MarkCoverage.glyphs, table.MarkArray.MarkRecord
            ):
                cp = reverse.get(name)
                original = cmap.get(cp)
                if original in canonical:
                    marks[glyph_maps[0][original]] = (
                        record.Class,
                        copy.deepcopy(canonical[original]),
                    )
            if not marks:
                continue
            classes = {index for index, _ in marks.values()}
            bases = {
                names[name]: {
                    index: copy.deepcopy(anchor)
                    for index, anchor in enumerate(record.BaseAnchor)
                    if anchor is not None and index in classes
                }
                for name, record in zip(
                    table.BaseCoverage.glyphs, table.BaseArray.BaseRecord
                )
            }
            subtable = buildMarkBasePosSubtable(
                marks, bases, merged.getReverseGlyphMap()
            )
            index = len(gpos.LookupList.Lookup)
            gpos.LookupList.Lookup.append(buildLookup([subtable]))
            for feature in gpos.FeatureList.FeatureRecord:
                if feature.FeatureTag == "mark":
                    feature.Feature.LookupListIndex.append(index)
                    feature.Feature.LookupCount = len(feature.Feature.LookupListIndex)
            added += 1
    gpos.LookupList.LookupCount = len(gpos.LookupList.Lookup)
    return added


def sort_features(table):
    records = table.FeatureList.FeatureRecord
    order = sorted(range(len(records)), key=lambda index: records[index].FeatureTag)
    remap = {old: new for new, old in enumerate(order)}
    table.FeatureList.FeatureRecord = [records[index] for index in order]
    table.FeatureList.FeatureCount = len(order)
    for record in table.ScriptList.ScriptRecord:
        systems = [record.Script.DefaultLangSys] + [
            item.LangSys for item in record.Script.LangSysRecord
        ]
        for system in systems:
            if system is None:
                continue
            system.FeatureIndex = sorted(remap[index] for index in system.FeatureIndex)
            if system.ReqFeatureIndex != 0xFFFF:
                system.ReqFeatureIndex = remap[system.ReqFeatureIndex]


def add_korean_forms(merged, names, variants):
    if not variants:
        return
    gsub = merged["GSUB"].table
    mapping = {
        merged.getBestCmap()[cp]: names[3][glyph] for cp, glyph in variants.items()
    }
    index = len(gsub.LookupList.Lookup)
    gsub.LookupList.Lookup.append(buildLookup([buildSingleSubstSubtable(mapping)]))
    gsub.LookupList.LookupCount = len(gsub.LookupList.Lookup)
    for script in gsub.ScriptList.ScriptRecord:
        if script.ScriptTag not in ("hani", "hang"):
            continue
        system = next(
            (
                item.LangSys
                for item in script.Script.LangSysRecord
                if item.LangSysTag == "KOR "
            ),
            None,
        )
        if system is None:
            language = otTables.LangSysRecord()
            language.LangSysTag = "KOR "
            language.LangSys = copy.deepcopy(script.Script.DefaultLangSys)
            script.Script.LangSysRecord.append(language)
            script.Script.LangSysRecord.sort(key=lambda item: item.LangSysTag)
            script.Script.LangSysCount = len(script.Script.LangSysRecord)
            system = language.LangSys
        previous = [
            item
            for item in system.FeatureIndex
            if gsub.FeatureList.FeatureRecord[item].FeatureTag == "locl"
        ]
        lookups = sorted(
            {
                lookup
                for item in previous
                for lookup in gsub.FeatureList.FeatureRecord[
                    item
                ].Feature.LookupListIndex
            }
        )
        record = otTables.FeatureRecord()
        record.FeatureTag = "locl"
        record.Feature = otTables.Feature()
        record.Feature.FeatureParams = None
        record.Feature.LookupListIndex = lookups + [index]
        record.Feature.LookupCount = len(record.Feature.LookupListIndex)
        feature_index = len(gsub.FeatureList.FeatureRecord)
        gsub.FeatureList.FeatureRecord.append(record)
        # Each language gets one locl feature; HarfBuzz chooses only the first duplicate tag.
        system.FeatureIndex = [
            item for item in system.FeatureIndex if item not in previous
        ] + [feature_index]
        system.FeatureCount = len(system.FeatureIndex)
    sort_features(gsub)


class TrackingMerger(Merger):
    def __init__(self, orders):
        super().__init__(Options(drop_tables=["BASE", "STAT"]))
        self.orders = orders
        self.glyph_maps = []

    def _preMerge(self, font):
        old = self.orders[len(self.glyph_maps)]
        self.glyph_maps.append(dict(zip(old, font.getGlyphOrder(), strict=True)))
        return super()._preMerge(font)


def vertical_metrics(font, reference):
    if "vmtx" in font:
        return
    font["vhea"] = copy.deepcopy(reference["vhea"])
    font["vmtx"] = newTable("vmtx")
    metrics = {}
    for name in font.getGlyphOrder():
        glyph = font["glyf"][name]
        height = getattr(glyph, "yMax", 0) - getattr(glyph, "yMin", 0)
        metrics[name] = 1000, max(0, (1000 - height) // 2)
    font["vmtx"].metrics = metrics


def copy_baselines(merged, japanese, korean):
    if "BASE" not in japanese:
        return
    merged["BASE"] = copy.deepcopy(japanese["BASE"])
    sx, sy, dx, dy, _ = PROFILES["NotoSansJP-ExtraBold.ttf"]
    for axis_name in ("HorizAxis", "VertAxis"):
        scale, offset = (sy, dy) if axis_name == "HorizAxis" else (sx, dx)
        axis = getattr(merged["BASE"].table, axis_name)
        other = getattr(korean["BASE"].table, axis_name)
        if axis is None:
            continue
        records = axis.BaseScriptList.BaseScriptRecord
        tags = {record.BaseScriptTag for record in records}
        records.extend(
            copy.deepcopy(record)
            for record in other.BaseScriptList.BaseScriptRecord
            if record.BaseScriptTag not in tags
        )
        records.sort(key=lambda record: record.BaseScriptTag)
        axis.BaseScriptList.BaseScriptCount = len(records)
        for record in records:
            for tag, coordinate in zip(
                axis.BaseTagList.BaselineTag, record.BaseScript.BaseValues.BaseCoord
            ):
                coordinate.Coordinate = (
                    0
                    if tag == "romn"
                    else otRound(coordinate.Coordinate * scale + offset)
                )


def metadata(font, original, source_fonts):
    names = font["name"]
    for record in list(names.names):
        if record.nameID < 256:
            names.names.remove(record)
    copyright = "\n".join(
        dict.fromkeys(source["name"].getDebugName(0) for source in source_fonts)
    )
    values = {
        0: copyright + "\nCopyright 2026 The Moxi Trust Contributors.",
        1: "Moxi Trust",
        2: "ExtraBold",
        3: "1.000;MOXI;MoxiTrust-ExtraBold",
        4: "Moxi Trust ExtraBold",
        5: "Version 1.000",
        6: "MoxiTrust-ExtraBold",
        9: "Moxi Trust Contributors; original Momo Trust, Noto and Adobe authors",
        10: "Momotrust glyphs preserved; adapted Noto ExtraBold multilingual glyphs. See OFL.txt and README.md.",
        13: "This Font Software is licensed under the SIL Open Font License, Version 1.1. See OFL.txt.",
        14: "https://openfontlicense.org",
        16: "Moxi Trust",
        17: "ExtraBold",
    }
    for name_id, value in values.items():
        names.setName(value, name_id, 3, 1, 0x409)
        names.setName(value, name_id, 0, 4, 0)
    font["head"].created = original["head"].created
    font["head"].modified = original["head"].created
    font["head"].fontRevision = 1.0
    font["head"].macStyle = 1
    for attr in ("ascent", "descent", "lineGap"):
        setattr(font["hhea"], attr, getattr(original["hhea"], attr))
    os2 = font["OS/2"]
    os2.usWeightClass = 800
    os2.fsSelection = (os2.fsSelection & ~0x41) | 0xA0
    os2.sTypoAscender = original["OS/2"].sTypoAscender
    os2.sTypoDescender = original["OS/2"].sTypoDescender
    os2.sTypoLineGap = original["OS/2"].sTypoLineGap
    os2.sxHeight = original["OS/2"].sxHeight
    os2.sCapHeight = original["OS/2"].sCapHeight
    os2.usWinAscent = max(os2.usWinAscent, font["head"].yMax)
    os2.usWinDescent = max(os2.usWinDescent, -font["head"].yMin)
    font["post"].formatType = 3.0


def validate_font(font, originals):
    coverage = set().union(*(original.getBestCmap() for original in originals))
    if set(font.getBestCmap()) != coverage:
        raise ValueError("Merged Unicode coverage differs from the source union")
    if len(font.getGlyphOrder()) >= 65535:
        raise ValueError("Merged font exceeds the TrueType glyph limit")
    for index, name in enumerate(originals[0].getGlyphOrder()):
        merged_name = font.getGlyphName(index)
        if glyph_signature(font, merged_name) != glyph_signature(originals[0], name):
            raise ValueError(f"Momotrust geometry or spacing changed: {name}")
        before = getattr(originals[0]["glyf"][name], "program", None)
        after = getattr(font["glyf"][merged_name], "program", None)
        if (before.getBytecode() if before else b"") != (
            after.getBytecode() if after else b""
        ):
            raise ValueError(f"Momotrust hinting changed: {name}")


def build(source_directory, output_directory):
    manifest = json.loads(SOURCE_MANIFEST.read_text())
    paths = [source_directory / name for name in PROFILES]
    for path in paths:
        if digest(path) != manifest["sources"][path.name]:
            raise ValueError(
                f"Source checksum changed: {path.name}. Inspect it before updating sources.json."
            )
    original_fonts = [TTFont(path, recalcTimestamp=False) for path in paths]
    for path, font in zip(paths, original_fonts):
        if "SIL Open Font License" not in font["name"].getDebugName(13):
            raise ValueError(f"Missing expected OFL license: {path.name}")
        if font["head"].unitsPerEm != 1000:
            raise ValueError(f"Unexpected em size: {path.name}")
    originals = [font.getBestCmap().copy() for font in original_fonts]
    variants = regional_han(original_fonts[2], original_fonts[3], set(originals[0]))
    fonts, orders, ownership, seen, changes = [], [], [], set(), {}
    with tempfile.TemporaryDirectory(prefix="moxi-font-build-") as temporary:
        prepared = []
        for index, path in enumerate(paths):
            font = TTFont(path, recalcTimestamp=False)
            owned = originals[index].keys() - seen
            seen.update(owned)
            ownership.append(set(owned))
            font._moxi_mark_codepoints = {
                name: cp for cp, name in originals[index].items() if cp in originals[0]
            }
            if index:
                marks = [
                    name
                    for name, cp in font._moxi_mark_codepoints.items()
                    if unicodedata.combining(chr(cp))
                ]
                prepare(
                    font,
                    set(owned),
                    marks + (list(variants.values()) if index == 3 else []),
                )
                changes[path.name] = adapt_outlines(font, PROFILES[path.name])
            vertical_metrics(font, original_fonts[2])
            orders.append(font.getGlyphOrder())
            fonts.append(font)
        merge_feature_names(fonts)
        for path, font in zip(paths, fonts):
            target = Path(temporary) / path.name
            font.save(target)
            prepared.append(target)
        merger = TrackingMerger(orders)
        merged = merger.merge(prepared)
        cross_marks = bridge_marks(merged, fonts, merger.glyph_maps)
        add_korean_forms(merged, merger.glyph_maps, variants)
        copy_baselines(merged, original_fonts[2], original_fonts[3])
        metadata(merged, original_fonts[0], original_fonts)
        merged.recalcTimestamp = False
        output_directory.mkdir(parents=True, exist_ok=True)
        ttf = Path(temporary) / "MoxiTrust-ExtraBold.ttf"
        merged.save(ttf)
        compressed = TTFont(ttf, recalcTimestamp=False)
        validate_font(compressed, original_fonts)
        compressed.flavor = "woff2"
        woff = ttf.with_suffix(".woff2")
        compressed.save(woff)
        validate_font(TTFont(woff, recalcTimestamp=False), original_fonts)
        report = {
            "family": "Moxi Trust",
            "weight": 800,
            "fonttools": fontTools.__version__,
            "sources": manifest["sources"],
            "codepoints": len(merged.getBestCmap()),
            "glyphs": len(merged.getGlyphOrder()),
            "koreanHanAlternates": len(variants),
            "crossFontMarkLookups": cross_marks,
            "roundedGlyphs": changes,
            "layoutFeatures": {
                tag: sorted(
                    {
                        record.FeatureTag
                        for record in merged[tag].table.FeatureList.FeatureRecord
                    }
                )
                for tag in ("GSUB", "GPOS")
            },
            "profiles": {
                name: {
                    "scaleX": profile[0],
                    "scaleY": profile[1],
                    "offsetX": profile[2],
                    "offsetY": profile[3],
                    "cornerRadius": profile[4],
                }
                for name, profile in PROFILES.items()
            },
            "codepointsBySource": {
                path.name: len(owned) for path, owned in zip(paths, ownership)
            },
            "artifacts": {
                path.name: {"bytes": path.stat().st_size, "sha256": digest(path)}
                for path in (ttf, woff)
            },
        }
        # Never expose a partially written font to a running shell or web server.
        for path in (ttf, woff):
            with tempfile.NamedTemporaryFile(
                dir=output_directory, prefix=".moxi-font-", delete=False
            ) as stream:
                staging = Path(stream.name)
                try:
                    stream.write(path.read_bytes())
                    stream.flush()
                    os.fsync(stream.fileno())
                    staging.chmod(0o644)
                    staging.replace(output_directory / path.name)
                finally:
                    staging.unlink(missing_ok=True)
        report_path = output_directory / "MoxiTrust-ExtraBold.json"
        report_path.write_text(json.dumps(report, indent=2) + "\n")
        return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sources",
        type=Path,
        help="directory containing the original TTFs; defaults to temporary recovery from pinned Git history",
    )
    parser.add_argument("--output", type=Path, default=FONT_DIRECTORY)
    args = parser.parse_args()
    logging.basicConfig(level=logging.WARNING)
    with source_directory(args.sources) as sources:
        report = build(sources, args.output)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
