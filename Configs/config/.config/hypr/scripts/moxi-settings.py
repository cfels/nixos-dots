#!/usr/bin/env python3
"""Read, update, and apply Moxi user preferences without rewriting dotfiles."""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import moxi_settings as settings


def run(*arguments):
    result = subprocess.run(
        arguments, capture_output=True, text=True, timeout=15, check=False
    )
    if result.returncode:
        raise RuntimeError(
            result.stderr.strip() or result.stdout.strip() or f"{arguments[0]} failed"
        )
    return result.stdout


def project_info():
    # Resolve through the deployed helper's real path, never the terminal's cwd.
    for repository in Path(__file__).resolve().parents:
        if (
            repository / "Configs/config/.config/hypr/scripts/moxi-settings.py"
        ).is_file() and (repository / ".git").exists():
            result = subprocess.run(
                [
                    "git",
                    "-C",
                    str(repository),
                    "log",
                    "-1",
                    "--format=commit: %s (%h)",
                ],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
            return {"commit": result.stdout.strip() or "Unavailable"}
    return {"commit": "Unavailable (Git metadata missing)"}


def launch(key):
    app = settings.get("applications." + key)
    if app.endswith(".desktop"):
        if Path(app).name != app:
            raise ValueError("Expected a desktop-entry ID, not a path")
        bases = [
            Path.home() / ".local/share",
            *map(
                Path,
                os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(
                    ":"
                ),
            ),
        ]
        for base in bases:
            path = base / "applications" / app
            if path.is_file():
                os.execlp("gio", "gio", "launch", str(path))
        raise ValueError(f"Desktop application is not installed: {app}")
    if not shutil.which(app):
        raise ValueError(f"Application is not installed: {app}")
    os.execlp(app, app)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        choices=(
            "read",
            "patch",
            "restore",
            "get",
            "apply",
            "generate",
            "launch",
            "info",
        ),
    )
    parser.add_argument("argument", nargs="?")
    args = parser.parse_args()
    if args.command == "read":
        settings.directory().mkdir(parents=True, exist_ok=True)
        document, values, _ = settings.load()
        print(
            json.dumps(
                {
                    "values": values,
                    "wallpapers": document.get("wallpapers", {}),
                    "overrides": document.get("values", {}),
                }
            )
        )
    elif args.command in ("patch", "restore"):
        apply_needed = False
        if args.command == "restore":
            apply_needed = settings.restore(json.loads(args.argument))
        else:
            settings.patch(json.loads(args.argument))
        document, values, _ = settings.load()
        print(
            json.dumps(
                {
                    "values": values,
                    "wallpapers": document.get("wallpapers", {}),
                    "overrides": document.get("values", {}),
                    "applyHyprland": apply_needed,
                }
            )
        )
    elif args.command == "get":
        value = settings.get(args.argument)
        print(
            str(Path(value).expanduser())
            if args.argument.endswith("Directory")
            else json.dumps(value)
            if not isinstance(value, str)
            else value
        )
    elif args.command in ("apply", "generate"):
        settings.generate_hyprland()
        if args.command == "apply":
            run("hyprctl", "reload")
            errors = run("hyprctl", "configerrors").strip()
            if errors and errors != "ok":
                raise RuntimeError(errors)
        print(
            "setting applied!"
            if args.command == "apply"
            else "setting maked!"
        )
    elif args.command == "launch":
        if args.argument not in (
            "terminal",
            "browser",
            "fileManager",
            "editor",
            "chat",
        ):
            raise ValueError("Unknown shortcut application")
        launch(args.argument)
    elif args.command == "info":
        print(json.dumps(project_info()))


if __name__ == "__main__":
    try:
        main()
    except (
        OSError,
        ValueError,
        TypeError,
        KeyError,
        RuntimeError,
        subprocess.SubprocessError,
    ) as error:
        print(f"Moxi Settings: {error}", file=sys.stderr)
        sys.exit(1)
