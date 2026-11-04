"""Exercise the real adapter against a private, speaker-free test audio service."""

import importlib.util
import json
import selectors
import subprocess
import sys
import time

spec = importlib.util.spec_from_file_location("audio", "/work/moxi-audio.py")
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)


def wait_for(predicate):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        state = audio.snapshot()
        if predicate(state):
            return state
        time.sleep(0.03)
    raise AssertionError("Audio state did not converge")


def request(action, kind, node, value):
    audio.command(
        {
            "action": action,
            "kind": kind,
            "id": node["id"],
            "serial": node["serial"],
            "value": value,
        }
    )


def main():
    audio.pactl("load-module", "module-null-sink", "sink_name=moxi_one")
    second_module = audio.pactl(
        "load-module", "module-null-sink", "sink_name=moxi_two"
    ).strip()
    audio.pactl(
        "load-module",
        "module-remap-source",
        "source_name=moxi_input",
        "master=moxi_one.monitor",
    )
    watcher = subprocess.Popen(
        [sys.executable, "-B", "/work/moxi-audio.py", "watch"],
        stdout=subprocess.PIPE,
        text=True,
    )
    player = None
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(watcher.stdout, selectors.EVENT_READ)
            assert selector.select(5), "No initial subscription snapshot"
            initial = json.loads(watcher.stdout.readline())
            assert len(initial["outputs"]) == 2 and len(initial["inputs"]) == 1, initial
            one, two = sorted(initial["outputs"], key=lambda node: node["name"])
            microphone = initial["inputs"][0]
            request("volume", "sink", one, 37)
            request("mute", "source", microphone, True)
            request("volume", "source", microphone, 61)
            request("default", "source", microphone, None)
            request("default", "sink", two, None)
            state = wait_for(
                lambda state: (
                    any(
                        node["name"] == "moxi_one" and node["volume"] == 37
                        for node in state["outputs"]
                    )
                    and state["inputs"][0]["muted"]
                    and state["inputs"][0]["volume"] == 61
                    and any(
                        node["name"] == "moxi_two" and node["default"]
                        for node in state["outputs"]
                    )
                )
            )
            # External tools must be reflected by the subscription, including default changes.
            audio.pactl("set-sink-volume", one["name"], "49%")
            audio.pactl("set-default-sink", one["name"])
            deadline = time.monotonic() + 5
            observed = False
            while time.monotonic() < deadline:
                if not selector.select(1):
                    continue
                update = json.loads(watcher.stdout.readline())
                if any(
                    node["name"] == "moxi_one"
                    and node["default"]
                    and node["volume"] == 49
                    for node in update["outputs"]
                ):
                    observed = True
                    break
            assert observed, "External default/volume changes were not published"
            player = subprocess.Popen(
                [
                    "pacat",
                    "--playback",
                    "--raw",
                    "--device=moxi_one",
                    "--client-name=MoxiAudioTest",
                ],
                stdin=subprocess.PIPE,
            )
            player.stdin.write(b"\0" * 4096)
            player.stdin.flush()
            state = wait_for(
                lambda state: any(
                    node["label"] == "MoxiAudioTest" for node in state["streams"]
                )
            )
            stream = next(
                node for node in state["streams"] if node["label"] == "MoxiAudioTest"
            )
            request("volume", "sink-input", stream, 24)
            request("mute", "sink-input", stream, True)
            request("route", "sink-input", stream, two["id"])
            wait_for(
                lambda state: any(
                    node["id"] == stream["id"]
                    and node["volume"] == 24
                    and node["muted"]
                    and node["sink"] == two["id"]
                    for node in state["streams"]
                )
            )
            audio.pactl("unload-module", second_module)
            wait_for(
                lambda state: all(node["id"] != two["id"] for node in state["outputs"])
            )
            try:
                request("volume", "sink", two, 50)
            except ValueError:
                pass
            else:
                raise AssertionError("Removed output was accepted")
            player.terminate()
            player.wait(timeout=3)
            player.stdin.close()
            player = None
            wait_for(
                lambda state: all(
                    node["serial"] != stream["serial"] for node in state["streams"]
                )
            )
            print("AUDIO_SETTINGS_OK")
    finally:
        if player:
            player.terminate()
            player.wait(timeout=3)
            player.stdin.close()
        watcher.terminate()
        watcher.wait(timeout=3)
        watcher.stdout.close()


if __name__ == "__main__":
    main()
