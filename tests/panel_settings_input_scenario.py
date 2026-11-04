"""Exercise real pointer grabs on a private X server, without host input."""

import ctypes
import json
import os
import subprocess
import time
from pathlib import Path


def wait_for(log, marker, count=1):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if log.read_text().count(marker) >= count:
            return
        time.sleep(0.03)
    raise AssertionError(f"Missing {marker} ({count}):\n{log.read_text()}")


def main():
    x11 = ctypes.CDLL(os.environ["X11_TEST_LIBRARY"])
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError("Cannot open isolated X display")
    xtst = ctypes.CDLL(os.environ["XTEST_TEST_LIBRARY"])
    xtst.XTestFakeMotionEvent.argtypes = [
        ctypes.c_void_p,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_ulong,
    ]
    xtst.XTestFakeButtonEvent.argtypes = [
        ctypes.c_void_p,
        ctypes.c_uint,
        ctypes.c_int,
        ctypes.c_ulong,
    ]

    def move(x, y):
        assert xtst.XTestFakeMotionEvent(display, -1, x, y, 0)
        x11.XSync(display, 0)
        time.sleep(0.025)

    def button(number, pressed):
        assert xtst.XTestFakeButtonEvent(display, number, pressed, 0)
        x11.XSync(display, 0)

    def drag(start, end):
        move(*start)
        button(1, True)
        for part in range(1, 13):
            move(*(round(a + (b - a) * part / 12) for a, b in zip(start, end)))
        button(1, False)
        time.sleep(0.7)

    log = Path("/work/pointer.log")
    with log.open("w") as output:
        shell = subprocess.Popen(
            ["qs", "-p", "/work/shell.qml", "--no-color"],
            stdout=output,
            stderr=output,
        )
        try:
            wait_for(log, "INPUT_READY")
            if os.environ.get("PANEL_REAL_CONTROLS") == "1":

                def click(name):
                    point = json.loads(
                        subprocess.check_output(
                            [
                                "qs",
                                "-p",
                                "/work/shell.qml",
                                "ipc",
                                "call",
                                "--",
                                "inspect",
                                "point",
                                name,
                            ],
                            text=True,
                        )
                    )
                    assert "error" not in point, (point, log.read_text())
                    move(round(point["x"]), round(point["y"]))
                    button(1, True)
                    button(1, False)
                    time.sleep(0.35)

                path = Path.home() / ".config/moxi/settings.json"

                def values():
                    return (
                        json.loads(path.read_text())["values"] if path.exists() else {}
                    )

                click("toggle:appearance.followWallpaper")
                assert values().get("appearance.followWallpaper") is False, (
                    values(),
                    log.read_text(),
                )
                click("slider:appearance.gapsIn")
                time.sleep(0.8)
                generated = Path.home() / ".config/moxi/hyprland-overrides.lua"
                assert generated.exists(), (
                    values(),
                    subprocess.check_output(
                        [
                            "qs",
                            "-p",
                            "/work/shell.qml",
                            "ipc",
                            "call",
                            "--",
                            "inspect",
                            "state",
                        ],
                        text=True,
                    ),
                    log.read_text(),
                )
                assert "gaps_in" in generated.read_text(), generated.read_text()
                assert "reload" in Path("/work/hyprctl.log").read_text()
                click("category:bar")
                click("choice:bar.clockFormat")
                click("12-hour")
                assert values().get("bar.clockFormat") == "12-hour", (
                    values(),
                    log.read_text(),
                )
                click("toggle:bar.visualizer")
                assert values().get("bar.visualizer") is False, (
                    values(),
                    log.read_text(),
                )
                click("category:notifications")
                click("toggle:notifications.dnd")
                assert values().get("notifications.dnd") is True, (
                    values(),
                    log.read_text(),
                )
                click("Restore defaults…")
                click("Cancel")
                assert values().get("bar.visualizer") is False, values()
                click("Restore defaults…")
                click("Restore defaults")
                assert values() == {}, (values(), log.read_text())
                time.sleep(0.8)
                assert "gaps_in" not in generated.read_text(), generated.read_text()
                assert json.loads(path.read_text())["wallpapers"] == {}, (
                    path.read_text()
                )
                print("PANEL_SETTINGS_INPUT_OK")
                return
            drag((550, 450), (350, 450))
            wait_for(log, "INPUT_PAGE settings")
            drag((205, 116), (510, 116))
            wait_for(log, "INPUT_SLIDER_OK")
            assert "INPUT_PAGE panel" not in log.read_text(), log.read_text()
            drag((700, 340), (700, 150))
            wait_for(log, "INPUT_SCROLL_OK")
            assert "INPUT_PAGE panel" not in log.read_text(), log.read_text()
            drag((350, 450), (550, 450))
            wait_for(log, "INPUT_PAGE panel")
            drag((350, 450), (550, 450))
            wait_for(log, "INPUT_PAGE settings", 2)
            drag((550, 450), (350, 450))
            wait_for(log, "INPUT_PAGE panel", 2)
            drag((550, 450), (350, 450))
            wait_for(log, "INPUT_PAGE settings", 3)
            time.sleep(0.7)
            # A touchpad wheel burst must switch once, even if momentum continues.
            move(500, 450)
            for _ in range(16):
                button(7, True)
                button(7, False)
                time.sleep(0.05)
            time.sleep(0.7)
            wait_for(log, "INPUT_PAGE panel", 3)
            assert log.read_text().count("INPUT_PAGE settings") == 3, log.read_text()
            print("PANEL_SETTINGS_INPUT_OK")
        finally:
            shell.terminate()
            shell.wait(timeout=3)
            x11.XCloseDisplay(display)


if __name__ == "__main__":
    main()
