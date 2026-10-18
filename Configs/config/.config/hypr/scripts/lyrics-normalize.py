#!/usr/bin/env python3
"""Convert provider payloads to the panel's line-timed LRC/JSON contract."""

import html
import json
import math
import re
import sys
import xml.etree.ElementTree as ET


def seconds(value):
    if value is None or isinstance(value, bool):
        return None
    text = str(value).strip()
    try:
        if text.endswith("ms"):
            result = float(text[:-2]) / 1000
        elif text.endswith("h"):
            result = float(text[:-1]) * 3600
        elif text.endswith("m"):
            result = float(text[:-1]) * 60
        elif text.endswith("s"):
            result = float(text[:-1])
        elif ":" in text:
            result = 0
            for part in text.split(":"):
                result = result * 60 + float(part)
        else:
            result = float(text)
        return result if math.isfinite(result) and result >= 0 else None
    except ValueError:
        return None


def lrc_stamp(value):
    millis = round(value * 1000)
    minutes, rest = divmod(millis, 60000)
    secs, millis = divmod(rest, 1000)
    return f"[{minutes:02d}:{secs:02d}.{millis:03d}]"


def lyric_text(text):
    return re.sub(r"(?<=\w)'{2,}(?=\w)", "'", text)


def result(lines, plain="", duration=0):
    lines = sorted(
        ((time, lyric_text(text.strip())) for time, text in lines if text.strip()),
        key=lambda line: line[0],
    )
    return {
        "duration": seconds(duration) or 0,
        "syncedLyrics": "\n".join(lrc_stamp(time) + text for time, text in lines),
        "plainLyrics": lyric_text(plain) or "\n".join(text for _, text in lines),
    }


def with_metadata(parsed, payload):
    sources = [payload]
    if isinstance(payload.get("metadata"), dict):
        sources.append(payload["metadata"])
    for source in sources:
        for field, keys in (
            ("title", ("title", "trackName", "songTitle", "song")),
            ("artist", ("artist", "artistName", "songArtist")),
            ("album", ("album", "albumName", "songAlbum")),
        ):
            for key in keys:
                value = source.get(key)
                if isinstance(value, str) and value.strip():
                    parsed[field] = value
                    break
        duration = seconds(source.get("duration", source.get("durationSeconds")))
        if duration:
            parsed["duration"] = duration
    return parsed


def element_text(node):
    # Alternate translations/transliterations and backing vocals aren't main lines.
    parts = [node.text or ""]
    for child in node:
        role = next((v for k, v in child.attrib.items() if k.split("}")[-1] == "role"), "")
        if role not in {"x-translation", "x-transliteration", "x-roman", "x-bg"}:
            parts.append(" " if child.tag.split("}")[-1] == "br" else element_text(child))
        parts.append(child.tail or "")
    return "".join(parts)


def text_lyrics(raw):
    raw = raw.lstrip("\ufeff").strip()
    if not raw:
        return result([])
    if raw.startswith("<"):
        # XML parsers replace literal attribute newlines with spaces. QQ stores
        # its whole QRC document here, so preserve the original line breaks.
        qrc_content = re.search(r"LyricContent\s*=\s*(['\"])(.*?)\1", raw, re.S)
        if qrc_content:
            return text_lyrics(html.unescape(qrc_content[2]))
        try:
            root = ET.fromstring(raw)
        except ET.ParseError:
            return result([])
        # QQ QRC can be wrapped in XML with its timings in an attribute.
        for node in root.iter():
            if "LyricContent" in node.attrib:
                return text_lyrics(node.attrib["LyricContent"])
        if root.tag.split("}")[-1] != "tt":
            return result([])
        lines = []
        plain = []
        for node in root.iter():
            if node.tag.split("}")[-1] != "p":
                continue
            text = re.sub(r"\s+", " ", element_text(node)).strip()
            if not text:
                continue
            plain.append(text)
            time = seconds(node.get("begin"))
            if time is None:
                times = [seconds(child.get("begin")) for child in node.iter()]
                time = min((t for t in times if t is not None), default=None)
            if time is not None:
                lines.append((time, text))
        return result(lines, "\n".join(plain))

    lines = []
    plain = []
    offset_match = re.search(r"\[offset:([+-]?\d+)\]", raw, re.I)
    # Positive LRC offsets advance lyrics relative to the playback clock.
    offset = -int(offset_match[1]) / 1000 if offset_match else 0
    for line in raw.splitlines():
        qrc = re.match(r"^\[(\d+),(\d+)\](.*)$", line)
        if qrc:
            text = re.sub(r"\(\d+,\d+(?:,\d+)?\)", "", qrc[3]).strip()
            lines.append((max(0, int(qrc[1]) / 1000 + offset), text))
            continue
        tags = re.match(r"^((?:\[\d+:\d+(?:[.:]\d+)?\])+)(.*)$", line)
        if tags:
            text = re.sub(r"<\d+:\d+(?:[.:]\d+)?>", "", tags[2]).strip()
            for minute, sec in re.findall(r"\[(\d+):(\d+(?:[.:]\d+)?)\]", tags[1]):
                time = int(minute) * 60 + float(sec.replace(":", "."))
                lines.append((max(0, time + offset), text))
        elif not re.match(r"^\[[a-z]+:", line, re.I) and line.strip():
            plain.append(line.strip())
    return result(lines, "\n".join(plain) if not lines else "")


def timed_rows(rows, kind=""):
    lines = []
    plain = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        text = row.get("text", row.get("words", ""))
        if isinstance(text, list):
            text = " ".join(word.get("text", "") for word in text if isinstance(word, dict))
        if not isinstance(text, str):
            continue
        if not text and isinstance(row.get("syllabus"), list):
            text = "".join(word.get("text", "") for word in row["syllabus"] if isinstance(word, dict) and not word.get("isBackground"))
        plain.append(text)
        time = None
        for key in ("time", "timestamp", "startTimeMs", "startTime"):
            if key in row:
                time = seconds(row[key])
                if time is not None and key != "startTime":
                    time /= 1000
                break
        if time is not None and kind.lower() not in {"none", "plain", "unsynced"}:
            lines.append((time, text))
    return result(lines, "\n".join(plain))


def normalize(payload, depth=0):
    if depth > 8:
        return result([])
    if isinstance(payload, str):
        raw = payload.strip()
        if raw.startswith(("{", "[", '"')):
            try:
                return normalize(json.loads(raw), depth + 1)
            except (ValueError, TypeError):
                pass
        return text_lyrics(raw)
    if not isinstance(payload, dict):
        return result([])
    if payload.get("error") or payload.get("isError") or payload.get("success") is False or payload.get("ok") is False:
        return result([])
    if payload.get("type") in {"error", "failed"}:
        return result([])
    if "syncedLyrics" in payload or "plainLyrics" in payload:
        parsed = normalize(payload.get("syncedLyrics") or "", depth + 1)
        plain = payload.get("plainLyrics")
        if isinstance(plain, str) and plain.strip():
            parsed["plainLyrics"] = lyric_text(plain)
        return with_metadata(parsed, payload)
    for key in ("ttml", "lyrics", "lrc", "content", "lines", "lyric", "data", "result", "response"):
        nested = payload.get(key)
        if isinstance(nested, list):
            parsed = timed_rows(nested, payload.get("type") or payload.get("syncType") or "")
        elif isinstance(nested, (str, dict)):
            parsed = normalize(nested, depth + 1)
        else:
            continue
        if parsed["syncedLyrics"] or parsed["plainLyrics"]:
            return with_metadata(parsed, payload)
    return result([])


if __name__ == "__main__":
    try:
        raw = sys.stdin.read()
        try:
            payload = json.loads(raw)
        except ValueError:
            payload = raw if raw.lstrip("\ufeff \t\r\n").startswith(("<", "[")) else {}
        output = normalize(payload)
        times = [
            int(minute) * 60 + float(sec)
            for minute, sec in re.findall(r"\[(\d+):(\d+\.\d+)\]", output["syncedLyrics"])
        ]
        duration = seconds(sys.argv[1]) if len(sys.argv) > 1 else None
        duration = duration or output["duration"]
        if times and (
            len(set(times)) < 2 or (duration > 0 and max(times) > duration + 3)
        ):
            output["syncedLyrics"] = ""
    except (ValueError, TypeError, OverflowError, ET.ParseError):
        output = result([])
    print(json.dumps(output, ensure_ascii=False, separators=(",", ":")))
