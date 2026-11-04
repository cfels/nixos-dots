"""Shared, versioned Moxi preferences. No hardware state belongs in this file."""

import fcntl
import json
import math
import os
import tempfile
from functools import cache
from pathlib import Path

SCHEMA = Path(__file__).resolve().parents[2] / "quickshell/moxi/settings/schema.json"


@cache
def schema():
    return json.loads(SCHEMA.read_text())


def directory():
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "moxi"


def settings_path():
    return directory() / "settings.json"


@cache
def defaults():
    return {item["key"]: item["default"] for item in schema()["settings"]}


def validate(key, value):
    item = next((item for item in schema()["settings"] if item["key"] == key), None)
    if item is None:
        raise ValueError(f"Unknown preference: {key}")
    kind = item["kind"]
    if kind == "toggle":
        valid = type(value) is bool
    elif kind in ("slider", "number"):
        valid = type(value) in (int, float) and math.isfinite(value)
        valid = valid and item["min"] <= value <= item["max"]
        if item.get("integer"):
            valid = valid and value == int(value)
    else:
        valid = isinstance(value, str) and len(value) <= 4096
        valid = valid and not any(ord(char) < 32 for char in value)
        if kind == "choice":
            valid = valid and value in item["choices"]
        if kind == "path":
            valid = valid and value.startswith(("/", "~/"))
        if key == "desktop.keyboardLayout":
            valid = valid and all(
                c.isascii() and (c.isalnum() or c in "_,") for c in value
            )
            valid = valid and 1 <= len(value) <= 80
    if not valid:
        raise ValueError(f"Invalid value for {key}: {value!r}")
    return value


def load():
    path = settings_path()
    try:
        raw = path.read_text()
    except FileNotFoundError:
        raw = None
    document = (
        json.loads(raw)
        if raw is not None
        else {"version": 1, "values": {}, "wallpapers": {}}
    )
    if not isinstance(document, dict) or document.get("version") != 1:
        raise ValueError("Expected a version 1 Moxi settings object")
    values = document.get("values", {})
    wallpapers = document.get("wallpapers", {})
    if not isinstance(values, dict) or not isinstance(wallpapers, dict):
        raise TypeError("values and wallpapers must be objects")
    for key, value in values.items():
        if key.startswith("premium."):
            raise ValueError("PremiumWalls preferences must be stored per wallpaper")
        validate(key, value)
    for path, overrides in wallpapers.items():
        if (
            not isinstance(path, str)
            or not path.startswith("/")
            or not isinstance(overrides, dict)
        ):
            raise ValueError(
                "Wallpaper overrides must be keyed by absolute manifest path"
            )
        for key, value in overrides.items():
            if not key.startswith("premium."):
                raise ValueError(
                    "Only PremiumWalls preferences may be overridden per wallpaper"
                )
            validate(key, value)
    merged = defaults() | values
    if raw is None:
        merged["notifications.dnd"] = (Path.home() / ".cache/moxi-dnd").exists()
    return document, merged, raw


def get(key):
    try:
        return load()[1][key]
    except (OSError, ValueError, TypeError):
        return defaults()[key]


def path_value(key):
    return str(Path(get(key)).expanduser())


def premium_overrides(path):
    try:
        return load()[0].get("wallpapers", {}).get(str(Path(path).resolve()), {})
    except (OSError, ValueError, TypeError):
        return {}


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", dir=path.parent, prefix=".moxi-", delete=False
        ) as stream:
            temporary = Path(stream.name)
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def patch(request):
    directory().mkdir(parents=True, exist_ok=True)
    with (directory() / "settings.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        document, merged, raw = load()
        wallpaper = request.get("wallpaper", "")
        if wallpaper:
            wallpaper = str(Path(wallpaper).resolve())
            target = document.setdefault("wallpapers", {}).setdefault(wallpaper, {})
        else:
            target = document.setdefault("values", {})
        for key, value in request["changes"].items():
            if wallpaper and not key.startswith("premium."):
                raise ValueError("Not a PremiumWalls preference")
            if not wallpaper and key.startswith("premium."):
                raise ValueError(
                    "Choose a PremiumWalls manifest before saving this preference"
                )
            validate(key, defaults()[key] if value is None else value)
            current = target.get(key) if wallpaper else merged[key]
            if (
                key not in request.get("expected", {})
                or request["expected"][key] != current
            ):
                raise ValueError(
                    f"{key} changed externally. Review its current value and try again."
                )
            if value is None:
                target.pop(key, None)
            else:
                target[key] = value
        if (
            raw is None
            and "notifications.dnd" not in request["changes"]
            and merged["notifications.dnd"]
        ):
            document["values"]["notifications.dnd"] = True
        if wallpaper and not target:
            document["wallpapers"].pop(wallpaper, None)
        # Editors need not honour our lock. Never knowingly overwrite an intervening edit.
        try:
            latest = settings_path().read_text()
        except FileNotFoundError:
            latest = None
        if latest != raw:
            raise ValueError("Settings changed while saving. Reload and try again.")
        atomic_write(
            settings_path(), json.dumps(document, indent=2, ensure_ascii=False) + "\n"
        )
        return load()[0]


def restore(request):
    """Remove only the selected overrides, rejecting edits since confirmation."""
    category = request.get("category")
    definitions = schema()["settings"]
    if category is not None and category not in {
        item["category"] for item in definitions
    }:
        raise ValueError("Unknown settings category")
    keys = {
        item["key"]
        for item in definitions
        if category is None or item["category"] == category
    }

    def selected(document):
        return {
            "values": {
                key: value
                for key, value in document.get("values", {}).items()
                if key in keys
            },
            "wallpapers": {
                path: {key: value for key, value in values.items() if key in keys}
                for path, values in document.get("wallpapers", {}).items()
                if any(key in keys for key in values)
            },
        }

    directory().mkdir(parents=True, exist_ok=True)
    with (directory() / "settings.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        document, _, raw = load()
        if selected(document) != selected(request["expected"]):
            raise ValueError(
                "Settings changed externally. Review them before restoring defaults."
            )
        removed = selected(document)
        document["values"] = {
            key: value
            for key, value in document.get("values", {}).items()
            if key not in keys
        }
        document["wallpapers"] = {
            path: {key: value for key, value in values.items() if key not in keys}
            for path, values in document.get("wallpapers", {}).items()
            if any(key not in keys for key in values)
        }
        latest = settings_path().read_text() if settings_path().exists() else None
        if latest != raw:
            raise ValueError("Settings changed while restoring. Reload and try again.")
        atomic_write(
            settings_path(), json.dumps(document, indent=2, ensure_ascii=False) + "\n"
        )
        return any(key in HYPRLAND for key in removed["values"])


HYPRLAND = {
    "appearance.gapsIn": ("general", "gaps_in"),
    "appearance.gapsOut": ("general", "gaps_out"),
    "appearance.borderSize": ("general", "border_size"),
    "appearance.rounding": ("decoration", "rounding"),
    "appearance.activeOpacity": ("decoration", "active_opacity"),
    "appearance.inactiveOpacity": ("decoration", "inactive_opacity"),
    "appearance.dimInactive": ("decoration", "dim_inactive"),
    "appearance.dimStrength": ("decoration", "dim_strength"),
    "appearance.blur": ("decoration", "blur", "enabled"),
    "appearance.blurSize": ("decoration", "blur", "size"),
    "appearance.blurPasses": ("decoration", "blur", "passes"),
    "appearance.shadows": ("decoration", "shadow", "enabled"),
    "appearance.motionBlur": ("decoration", "motion_blur", "enabled"),
    "advanced.motionSamples": ("decoration", "motion_blur", "samples"),
    "appearance.animations": ("animations", "enabled"),
    "desktop.keyboardLayout": ("input", "kb_layout"),
    "desktop.sensitivity": ("input", "sensitivity"),
}


def lua(value):
    if isinstance(value, dict):
        return (
            "{ "
            + ", ".join(key + " = " + lua(item) for key, item in value.items())
            + " }"
        )
    return json.dumps(value, ensure_ascii=True)


def generate_hyprland():
    document, _, _ = load()
    config = {}
    for key, location in HYPRLAND.items():
        if key not in document.get("values", {}):
            continue
        target = config
        for part in location[:-1]:
            target = target.setdefault(part, {})
        target[location[-1]] = document["values"][key]
    destination = directory() / "hyprland-overrides.lua"
    atomic_write(
        destination,
        "-- Generated by Moxi Settings; edit settings.json instead.\nhl.config("
        + lua(config)
        + ")\n",
    )
    return destination
