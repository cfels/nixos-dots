#!/usr/bin/env python3
"""Publish Matugen colors and ask running Qt/GTK apps to refresh them."""

import configparser
import io
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET


def run(*args):
    if not shutil.which(args[0]):
        return None
    result = subprocess.run(args, text=True, capture_output=True, check=False)
    if result.returncode:
        print(f"Theme refresh: {args[0]}: {result.stderr.strip()}", file=sys.stderr)
    return result


def apply():
    config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))

    run("kde-colors-apply")
    globals_file = config / "kdeglobals"
    palette = configparser.ConfigParser(interpolation=None)
    palette.read(globals_file)
    accent = "#" + "".join(f"{int(value):02x}" for value in palette["Colors:Button"]["ForegroundActive"].split(","))
    ink = "#" + "".join(f"{int(value):02x}" for value in palette["Colors:View"]["BackgroundNormal"].split(","))
    source = Path("/run/current-system/sw/share/icons/breeze-dark")
    icons = data / "icons/MoxiMatugen"
    directories = []
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    folders = sorted((source / "places").iterdir()) + sorted((source / "mimetypes").iterdir())
    for folder in folders:
        if not folder.name.isdecimal():
            continue
        relative = folder.relative_to(source).as_posix()
        target = icons / relative
        target.mkdir(parents=True, exist_ok=True)
        directories.append(relative)
        for original in folder.glob("*.svg"):
            if folder.parent.name == "mimetypes" and original.name != "inode-directory.svg":
                continue
            tree = ET.parse(original)
            if not any(element.get("class") == "ColorScheme-Accent" for element in tree.iter()):
                continue
            for element in tree.iter():
                role = element.get("class")
                style = element.get("style", "")
                if role == "ColorScheme-Accent":
                    element.set("style", style.replace("currentColor", accent))
                    del element.attrib["class"]
                elif role == "ColorScheme-Text" and "fill:currentColor" in style:
                    element.set("style", re.sub(r"fill-opacity:[\d.]+;?", "", style).replace("currentColor", ink))
                    del element.attrib["class"]
            tree.write(target / original.name, encoding="unicode")
    index = "[Icon Theme]\nName=Moxi Matugen\nInherits=breeze-dark,hicolor\nDirectories=" + ",".join(directories) + "\n"
    for directory in directories:
        context = "Places" if directory.startswith("places/") else "MimeTypes"
        index += f"\n[{directory}]\nSize={directory.rsplit('/', 1)[1]}\nContext={context}\nType=Fixed\n"
    (icons / "index.theme").write_text(index)
    if globals_file.is_file():
        text = globals_file.read_text().rstrip() + "\n"
        # Kvantum's fixed SVG colors do not follow the KDE palette.
        def breeze_style(match):
            group = match.group(0)
            if re.search(r'^widgetStyle=', group, flags=re.M):
                return re.sub(r'^widgetStyle=.*$', 'widgetStyle=breeze', group, flags=re.M)
            return group.rstrip() + '\nwidgetStyle=breeze\n\n'
        text, count = re.subn(r'^\[KDE\]\n.*?(?=^\[|\Z)', breeze_style, text, flags=re.M | re.S)
        if not count:
            text += '\n[KDE]\nwidgetStyle=breeze\n'
        text, count = re.subn(r'^\[Icons\]\n.*?(?=^\[|\Z)', '[Icons]\nTheme=MoxiMatugen\n\n', text, flags=re.M | re.S)
        if not count:
            text += '\n[Icons]\nTheme=MoxiMatugen\n'
        globals_file.write_text(text.rstrip() + "\n")
    # Also replace a previously loaded fixed style in running Qt widgets.
    run("dbus-send", "--session", "--type=signal", "/KGlobalSettings",
        "org.kde.KGlobalSettings.notifyChange", "int32:2", "int32:0")
    # The same palette notification used by KDE's Colors settings panel.
    run("dbus-send", "--session", "--type=signal", "/KGlobalSettings",
        "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0")
    run("dbus-send", "--session", "--type=signal", "/KIconLoader",
        "org.kde.KIconLoader.iconChanged", "int32:0")

    result = run("dconf", "read", "/org/gnome/desktop/interface/gtk-theme")
    current = result.stdout.strip().strip("'") if result and not result.returncode else ""
    name = "MoxiMatugen-B" if current == "MoxiMatugen-A" else "MoxiMatugen-A"

    # A new name makes GTK reload its theme provider, including named colors.
    # GTK 4 only loads its user stylesheet once, so its dynamic rules belong
    # in the theme provider that GTK reloads on this notification.
    for version in ("3.0", "4.0"):
        colors = (config / f"gtk-{version}/colors.css").read_text().replace("@import 'gtk.css';", "")
        base = Path(f"/run/current-system/sw/share/themes/Breeze/gtk-{version}/gtk-dark.css")
        if not base.is_file():
            raise FileNotFoundError(f"Breeze GTK {version} theme is unavailable")
        theme = data / "themes" / name / f"gtk-{version}"
        theme.mkdir(parents=True, exist_ok=True)
        css = f'@import url("{base}");\n{colors}\n'
        if version == "4.0":
            css += (cache / "moxi-theme/gtk-4.0/gtk.css").read_text()
        for filename in ("gtk.css", "gtk-dark.css"):
            (theme / filename).write_text(css)

        settings_file = config / f"gtk-{version}/settings.ini"
        settings = configparser.ConfigParser(interpolation=None)
        settings.optionxform = str
        settings.read(settings_file)
        if not settings.has_section("Settings"):
            settings.add_section("Settings")
        settings["Settings"]["gtk-theme-name"] = name
        settings["Settings"]["gtk-icon-theme-name"] = "MoxiMatugen"
        settings["Settings"]["gtk-application-prefer-dark-theme"] = "true"
        if version == "3.0":
            modules = settings["Settings"].get("gtk-modules", "").split(":")
            if "colorreload-gtk-module" not in modules:
                modules.append("colorreload-gtk-module")
            settings["Settings"]["gtk-modules"] = ":".join(filter(None, modules))
        text = io.StringIO()
        settings.write(text, space_around_delimiters=False)
        settings_file.write_text(text.getvalue().rstrip() + "\n")

    run("dconf", "write", "/org/gnome/desktop/interface/color-scheme", "'prefer-dark'")
    run("dconf", "write", "/org/gnome/desktop/interface/gtk-theme", f"'{name}'")
    run("dconf", "write", "/org/gnome/desktop/interface/icon-theme", "'MoxiMatugen'")

    xsettings = config / "xsettingsd/xsettingsd.conf"
    if xsettings.is_file():
        text = xsettings.read_text()
        text, count = re.subn(r'^Net/ThemeName\s+.*$', f'Net/ThemeName "{name}"', text, flags=re.M)
        if not count:
            text += f'\nNet/ThemeName "{name}"\n'
        text, count = re.subn(r'^Net/IconThemeName\s+.*$', 'Net/IconThemeName "MoxiMatugen"', text, flags=re.M)
        if not count:
            text += '\nNet/IconThemeName "MoxiMatugen"\n'
        xsettings.write_text(text)
        if subprocess.run(["pgrep", "-x", "xsettingsd"], capture_output=True).returncode == 0:
            run("pkill", "-HUP", "-x", "xsettingsd")

    # The GTK 3 module watches this file; reload after gtk.css is complete too.
    os.utime(config / "gtk-3.0/colors.css", None)


if __name__ == "__main__":
    apply()
