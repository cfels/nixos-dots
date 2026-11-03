#!/usr/bin/env python3
"""Validate PremiumWalls manifests and reserve startup playback per graphical session."""

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path


def describe(path):
    path = Path(path).resolve(strict=True)
    data = json.loads(path.read_text())
    if (
        not isinstance(data, dict)
        or data.get("version") != 1
        or data.get("type") != "velina"
    ):
        raise ValueError("expected a version 1 Velina PremiumWalls manifest")
    result = {"id": "velina", "name": "Velina"}
    for key in ("opening", "showcase", "poster", "openingPoster", "leafTexture"):
        value = data.get(key)
        if not isinstance(value, str) or not value or "\n" in value or "\t" in value:
            raise ValueError(f"{key} must name a local asset")
        source = (path.parent / value).resolve(strict=True)
        if not source.is_file():
            raise ValueError(f"{key} is not a file: {source}")
        result[key] = source.as_uri()
        result[key + "Path"] = str(source)
    for key in ("openingEnabled", "startupAudio", "loop", "pauseWhenFullscreen"):
        value = data.get(key, True)
        if not isinstance(value, bool):
            raise TypeError(f"{key} must be true or false")
        result[key] = value
    quality = data.get("effectsQuality", "high")
    if quality not in ("off", "low", "high"):
        raise ValueError("effectsQuality must be off, low, or high")
    result["effectsQuality"] = quality
    fit = data.get("fit", "cover")
    if fit not in ("cover", "contain"):
        raise ValueError("fit must be cover or contain")
    result["fit"] = fit
    return result


def session_directory():
    # The compositor signature changes on graphical login, unlike the user runtime dir.
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        session = os.environ.get("XDG_SESSION_ID")
        display = os.environ.get("WAYLAND_DISPLAY") or os.environ.get("DISPLAY")
        if not session or not display:
            raise RuntimeError("cannot identify the graphical session")
        signature = session + ":" + display
    digest = hashlib.sha256(signature.encode()).hexdigest()[:24]
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", Path.home() / ".cache"))
    directory = runtime / "moxi-wallpaper" / "premium-sessions" / digest
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    return directory


def reserve(path):
    try:
        with path.open("x") as marker:
            marker.write("reserved\n")
        return True
    except FileExistsError:
        return False


def claim(output, audio):
    directory = session_directory()
    key = hashlib.sha256(output.encode()).hexdigest()[:24]
    opening = reserve(directory / f"velina-{key}.opening")
    sound = opening and audio and reserve(directory / "velina.audio")
    return {"opening": opening, "audio": bool(sound)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("describe", "preview"):
        command = commands.add_parser(name)
        command.add_argument("manifest")
        if name == "preview":
            command.add_argument("--animated", action="store_true")
    reserve_parser = commands.add_parser("claim")
    reserve_parser.add_argument("output")
    reserve_parser.add_argument("--audio", action="store_true")
    args = parser.parse_args()
    if args.command == "claim":
        print(json.dumps(claim(args.output, args.audio)))
    else:
        data = describe(args.manifest)
        if args.command == "preview":
            print(data["showcasePath"] if args.animated else data["posterPath"])
        else:
            print(json.dumps(data))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, TypeError, RuntimeError) as error:
        sys.exit(f"PremiumWalls: {error}")
