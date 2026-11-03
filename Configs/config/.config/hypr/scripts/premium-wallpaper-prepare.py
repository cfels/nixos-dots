#!/usr/bin/env python3
"""Prepare local Velina media without changing or re-encoding the source videos."""

import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path


def probe(path):
    return json.loads(
        subprocess.check_output(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_streams",
                "-show_format",
                "-of",
                "json",
                str(path),
            ]
        )
    )


def prepare(extracted, continuation, destination):
    sources = {
        "opening.mp4": extracted / "quality-render/Velina-opening-HQ-with-sound.mp4",
        "showcase.mp4": continuation / "Velina-showcase-HQ.mp4",
        "LeafPar00.png": extracted / "background/LeafPar00.png",
    }
    metadata = {}
    for name, source in sources.items():
        if not source.is_file():
            raise FileNotFoundError(source)
        if source.suffix == ".mp4":
            info = probe(source)
            video = next(
                stream for stream in info["streams"] if stream["codec_type"] == "video"
            )
            if (video["width"], video["height"], video["avg_frame_rate"]) != (
                1920,
                1080,
                "60/1",
            ):
                raise ValueError(f"expected the 1080p60 export: {source}")
            audio = [
                stream for stream in info["streams"] if stream["codec_type"] == "audio"
            ]
            if bool(audio) != (name == "opening.mp4"):
                raise ValueError(f"expected audio only in the opening: {source}")
            metadata[name] = {
                "streams": info["streams"],
                "duration": info["format"]["duration"],
            }
    destination.mkdir(parents=True, exist_ok=False)
    for name, source in sources.items():
        shutil.copy2(source, destination / name)
        metadata.setdefault(name, {}).update(
            {
                "source": str(source.resolve()),
                "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            }
        )
    for video, poster in (
        ("opening.mp4", "opening-poster.png"),
        ("showcase.mp4", "poster.png"),
    ):
        subprocess.run(
            [
                "ffmpeg",
                "-v",
                "error",
                "-n",
                "-i",
                str(destination / video),
                "-frames:v",
                "1",
                str(destination / poster),
            ],
            check=True,
        )
    (destination / "source.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"PremiumWalls media prepared in {destination}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("extracted", type=Path)
    parser.add_argument("continuation", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    prepare(
        args.extracted.resolve(),
        args.continuation.resolve(),
        args.destination.resolve(),
    )


if __name__ == "__main__":
    main()
