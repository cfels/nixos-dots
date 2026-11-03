"""Run the prepared Velina clips through the real renderer in an isolated desktop."""

import argparse
import json
import shutil
import subprocess
from pathlib import Path

from support import REPO, IsolatedDesktop


def environment():
    module = Path(max(Path("/nix/store").glob("*-qtmultimedia-*/lib/qt-6")))
    return {
        "QT_QPA_PLATFORM": "xcb",
        "QSG_RHI_BACKEND": "opengl",
        "LIBGL_ALWAYS_SOFTWARE": "1",
        "DISPLAY": ":99",
        "QT_MEDIA_BACKEND": "ffmpeg",
        "XDG_RUNTIME_DIR": "/tmp/runtime",
        "HYPRLAND_INSTANCE_SIGNATURE": "native-velina-test",
        "QML_IMPORT_PATH": str(module / "qml") + ":/run/current-system/sw/lib/qt-6/qml",
        "QT_PLUGIN_PATH": str(module / "plugins"),
        "LIBGL_DRIVERS_PATH": str(Path("/run/opengl-driver/lib/dri").resolve()),
        "LD_LIBRARY_PATH": str(Path("/run/opengl-driver/lib").resolve()),
        "DBUS_SESSION_BUS_ADDRESS": "unix:path=/tmp/no-bus",
        "LANG": "C.UTF-8",
    }


def run(report, measure_only):
    desktop = IsolatedDesktop()
    try:
        shutil.copytree(
            REPO / "Configs/config/.config/quickshell/moxi/wallpaper",
            desktop.work / "wallpaper",
        )
        helper = desktop.home / ".config/hypr/scripts/premium-wallpaper.py"
        helper.parent.mkdir(parents=True)
        shutil.copy2(
            REPO / "Configs/config/.config/hypr/scripts/premium-wallpaper.py", helper
        )
        shutil.copytree(
            REPO / "Configs/walls/walls/PremiumWalls", desktop.work / "PremiumWalls"
        )
        shutil.copy2(
            REPO / "Configs/walls/walls/Velina.premiumwall.json",
            desktop.work / "Velina.premiumwall.json",
        )
        shutil.copy2(
            REPO / "tests/qml/PremiumWallpaperNativeScenario.qml",
            desktop.work / "shell.qml",
        )
        (desktop.work / "run.sh").write_text("""set -euo pipefail
Xvfb :99 -screen 0 960x540x24 -nolisten tcp >/work/xvfb.log 2>&1 &
server=$!
trap 'kill "$server"; wait "$server" || true' EXIT
for attempt in {1..100}; do
    [[ -S /tmp/.X11-unix/X99 ]] && break
    sleep 0.02
done
qs -p /work/shell.qml --no-color
""")
        settings = environment()
        if measure_only:
            settings["MOXI_NATIVE_CAPTURE"] = "0"
        result = subprocess.run(
            desktop.command("/work/run.sh", **settings),
            capture_output=True,
            text=True,
            timeout=40,
            check=False,
        )
        output = result.stdout + result.stderr
        report.mkdir(parents=True, exist_ok=True)
        (report / "playback.log").write_text(output)
        for image in desktop.work.glob("native-*.png"):
            shutil.copy2(image, report / image.name)
        if result.returncode or "NATIVE_OK" not in output:
            raise RuntimeError(f"native playback failed; see {report}/playback.log")
        for message in (
            "TypeError",
            "ReferenceError",
            "Binding loop",
            "NATIVE_FAILED",
            "NATIVE_TIMEOUT",
        ):
            if message in output:
                raise RuntimeError(f"{message}; see {report}/playback.log")
        metrics = next(
            line.split("NATIVE_OK ", 1)[1]
            for line in output.splitlines()
            if "NATIVE_OK " in line
        )
        metrics = json.loads(metrics)
        (report / "metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")
        print(json.dumps(metrics))
        print(f"Native playback reports saved to {report}")
    finally:
        desktop.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--measure-only", action="store_true")
    args = parser.parse_args()
    run(args.report.resolve(), args.measure_only)


if __name__ == "__main__":
    main()
