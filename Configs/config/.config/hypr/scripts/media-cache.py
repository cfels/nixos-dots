#!/usr/bin/env python3
import hashlib
import json
import math
import os
from pathlib import Path
import sys
import tempfile
import time


MAX_CACHE_BYTES = 150 * 1024 * 1024


def valid(payload):
    return (
        isinstance(payload, dict)
        and type(payload.get("duration")) in (int, float)
        and math.isfinite(payload["duration"])
        and payload["duration"] >= 0
        and isinstance(payload.get("syncedLyrics"), str)
        and isinstance(payload.get("plainLyrics"), str)
        and not payload.get("retryable")
    )


def prune(cache):
    entries = []
    for directory, pattern in ((cache / "lyrics/v1", "*.json"), (cache / "art", "art-*.img")):
        for entry in directory.glob(pattern):
            try:
                stat = entry.stat()
                entries.append((stat.st_mtime_ns, stat.st_size, entry))
            except FileNotFoundError:
                continue
    total = sum(size for _, size, _ in entries)
    for _, size, entry in sorted(entries):
        if total <= MAX_CACHE_BYTES:
            break
        entry.unlink(missing_ok=True)
        total -= size


def main():
    root = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "moxi"
    if sys.argv[1] == "prune":
        prune(root)
        return 0
    cache = root / "lyrics/v1"
    identity = [*sys.argv[2:], os.environ.get("LYRICSPLUS_URL", ""), os.environ.get("LRCMUX_URL", "")]
    key = hashlib.sha256(json.dumps(identity, ensure_ascii=False).encode()).hexdigest()
    target = cache / (key + ".json")
    now = time.time()
    if sys.argv[1] == "read":
        try:
            if target.stat().st_size > 2 * 1024 * 1024:
                return 1
            payload = json.loads(target.read_text())
            has_lyrics = valid(payload) and bool(payload["syncedLyrics"] or payload["plainLyrics"])
            if valid(payload) and (has_lyrics or 0 <= now - target.stat().st_mtime < 900):
                if has_lyrics:
                    target.touch()
                prune(root)
                print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
                return 0
        except (OSError, ValueError):
            pass
        return 1

    raw = sys.stdin.read(2 * 1024 * 1024 + 1)
    if len(raw.encode()) > 2 * 1024 * 1024:
        return 1
    payload = json.loads(raw)
    if not valid(payload):
        return 1
    cache.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=cache, prefix=".lyrics-", delete=False) as output:
            temporary = Path(output.name)
            json.dump(payload, output, ensure_ascii=False, separators=(",", ":"))
        temporary.replace(target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    prune(root)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f"Media cache: {error}", file=sys.stderr)
        sys.exit(1)
