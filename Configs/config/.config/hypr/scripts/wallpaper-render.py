#!/usr/bin/env python3
import argparse
import glob
import json
import os
import secrets
import shutil
import subprocess
import sys
import time
from pathlib import Path


def renderer_environment():
    environment = dict(os.environ)
    module = Path("/run/current-system/sw/lib/qt-6/qml/QtMultimedia")
    if not module.is_dir():
        # Existing sessions can use the installed module before the next Nix activation.
        installed = sorted(
            glob.glob("/nix/store/*-qtmultimedia-*/lib/qt-6/qml/QtMultimedia")
        )
        if not installed:
            raise RuntimeError("Qt Multimedia is required for wallpaper playback")
        module = Path(installed[-1])
    for name, path in (
        ("QML_IMPORT_PATH", module.parent),
        ("QT_PLUGIN_PATH", module.parent.parent / "plugins"),
    ):
        environment[name] = str(path) + os.pathsep + environment.get(name, "")
    environment["QT_MEDIA_BACKEND"] = "ffmpeg"
    return environment


class Renderer:
    def __init__(self, runtime):
        executable = shutil.which("qs")
        if executable is None:
            raise RuntimeError("Quickshell is required for wallpaper switching")
        self.config = (
            Path(__file__).resolve().parents[2] / "quickshell/moxi/wallpaper.qml"
        )
        self.command = [executable, "-p", str(self.config)]
        self.runtime = runtime

    def ipc(self, *arguments):
        return subprocess.run(
            [*self.command, "ipc", "call", "--", "wallpaper", *arguments],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )

    def ensure_running(self):
        if (
            result := self.ipc("ping")
        ).returncode == 0 and result.stdout.strip() == "ready":
            return
        environment = renderer_environment()
        with (self.runtime / "renderer-start.log").open("w") as log:
            process = subprocess.Popen(
                [*self.command, "--no-duplicate", "--no-color"],
                stdin=subprocess.DEVNULL,
                stdout=log,
                stderr=subprocess.STDOUT,
                env=environment,
                start_new_session=True,
                close_fds=True,
            )
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if (
                result := self.ipc("ping")
            ).returncode == 0 and result.stdout.strip() == "ready":
                return
            if process.poll() is not None:
                break
            time.sleep(0.05)
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        raise RuntimeError(
            f"wallpaper renderer did not start; see {self.runtime}/renderer-start.log"
        )

    def retire_legacy(self):
        # Leave the old wallpaper visible until this renderer completes a handoff.
        # Opening/audio reservations are session files, shared by both entry paths.
        legacy = self.config.parent / "wallpaper/shell.qml"
        result = subprocess.run(
            [
                self.command[0],
                "-p",
                str(legacy),
                "ipc",
                "call",
                "--",
                "wallpaper",
                "ping",
            ],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
        if result.returncode == 0 and result.stdout.strip() == "ready":
            stopped = subprocess.run(
                [self.command[0], "-p", str(legacy), "kill"],
                capture_output=True,
                text=True,
                timeout=3,
                check=False,
            )
            if stopped.returncode:
                raise RuntimeError(
                    stopped.stderr.strip()
                    or "Could not stop the legacy wallpaper renderer"
                )

    def set_wallpaper(self, path):
        request = secrets.token_hex(8)
        result = self.ipc("set", path, request)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or "wallpaper request failed")
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            result = self.ipc("status")
            if result.returncode:
                raise RuntimeError(
                    result.stderr.strip() or "wallpaper renderer disconnected"
                )
            if not result.stdout.strip():
                # Quickshell can briefly acknowledge IPC without a reply during reload.
                time.sleep(0.02)
                continue
            status = json.loads(result.stdout)
            if status["request"] != request:
                raise RuntimeError("wallpaper request was replaced by another client")
            if status["state"] == "failed":
                raise RuntimeError(status["error"])
            if status["state"] == "ready":
                self.retire_legacy()
                startup_log = self.runtime / "renderer-start.log"
                if startup_log.exists():
                    startup_log.replace(self.runtime / "renderer.log")
                return
            time.sleep(0.02)
        raise TimeoutError("wallpaper transition did not finish")


def main():
    parser = argparse.ArgumentParser(
        description="Control the independent wallpaper renderer"
    )
    parser.add_argument("path", nargs="?")
    parser.add_argument("--status", action="store_true")
    args = parser.parse_args()
    runtime = (
        Path(os.environ.get("XDG_RUNTIME_DIR", str(Path.home() / ".cache")))
        / "moxi-wallpaper"
    )
    renderer = Renderer(runtime)
    if args.status:
        result = renderer.ipc("status")
        if result.returncode or not result.stdout.strip():
            raise RuntimeError(
                result.stderr.strip() or "Wallpaper renderer is not running"
            )
        print(json.dumps(json.loads(result.stdout)))
        return
    if args.path is None:
        parser.error("choose a wallpaper or use --status")
    renderer.ensure_running()
    renderer.set_wallpaper(args.path)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(f"Wallpaper: {error}")
