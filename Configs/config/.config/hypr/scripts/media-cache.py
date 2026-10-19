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
MAX_ENTRY_BYTES = 2 * 1024 * 1024


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


def prune(cache, protected=None):
    entries = []
    directories = (
        (cache / "lyrics/v1", "*.json"),
        (cache / "art", "art-*.img"),
    )

    for directory, pattern in directories:
        try:
            for entry in directory.glob(pattern):
                try:
                    stat = entry.stat()
                    if entry.is_file():
                        entries.append((stat.st_mtime_ns, stat.st_size, entry))
                except OSError:
                    continue
        except OSError:
            continue

    total = sum(size for _, size, _ in entries)
    if total <= MAX_CACHE_BYTES:
        return

    for _, size, entry in sorted(entries):
        if total <= MAX_CACHE_BYTES:
            break
        if protected is not None and entry == protected:
            continue
        try:
            entry.unlink()
            total -= size
        except FileNotFoundError:
            continue
        except OSError as error:
            # Log the error but don't fail the whole process
            print(f"Media cache: {error}", file=sys.stderr)
            continue


def main():
    root = Path(
        os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache"
    ) / "moxi"

    if len(sys.argv) < 2:
        return 1

    if sys.argv[1] == "prune":
        try:
            prune(root)
        except Exception as e:
            print(f"Cache pruning failed: {e}", file=sys.stderr)
        return 0

    cache = root / "lyrics/v1"
    identity = [
        *sys.argv[2:],
        os.environ.get("LYRICSPLUS_URL", ""),
        os.environ.get("LRCMUX_URL", ""),
    ]
    key = hashlib.sha256(
        json.dumps(identity, ensure_ascii=False).encode()
    ).hexdigest()
    target = cache / (key + ".json")
    now = time.time()

    if sys.argv[1] == "read":
        try:
            stat = target.stat()
            if stat.st_size > MAX_ENTRY_BYTES:
                target.unlink(missing_ok=True)
                return 1

            payload = json.loads(target.read_text(encoding="utf-8"))
            if not valid(payload):
                target.unlink(missing_ok=True)
                return 1

            has_lyrics = bool(
                payload["syncedLyrics"] or payload["plainLyrics"]
            )

            if has_lyrics or 0 <= now - stat.st_mtime < 900:
                if has_lyrics:
                    target.touch()
                prune(root, protected=target)
                print(json.dumps(
                    payload,
                    ensure_ascii=False,
                    separators=(",", ":"),
                ))
                return 0

            target.unlink(missing_ok=True)
        except (OSError, ValueError) as e:
            # If there's an error reading or parsing the file, just return 1 to indicate no cache
            print(f"Cache read failed: {e}", file=sys.stderr)
            return 1

        return 1

    if sys.argv[1] != "write":
        return 1

    raw = sys.stdin.read(MAX_ENTRY_BYTES + 1)
    if len(raw.encode("utf-8")) > MAX_ENTRY_BYTES:
        return 1

    try:
        payload = json.loads(raw)
    except (ValueError, TypeError):
        return 1

    if not valid(payload):
        return 1

    cache.mkdir(parents=True, exist_ok=True)
    temporary = None

    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=cache,
            prefix=".lyrics-",
            delete=False,
        ) as output:
            temporary = Path(output.name)
            json.dump(
                payload,
                output,
                ensure_ascii=False,
                separators=(",", ":"),
            )

        temporary.replace(target)
        prune(root, protected=target)
    except Exception as e:
        # If there's an error writing the cache, clean up and return failure
        if temporary is not None:
            temporary.unlink(missing_ok=True)
        print(f"Cache write failed: {e}", file=sys.stderr)
        return 1
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f"Media cache: {error}", file=sys.stderr)
        sys.exit(1)