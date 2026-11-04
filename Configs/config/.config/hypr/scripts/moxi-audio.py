#!/usr/bin/env python3
"""Event-driven audio control through the existing PipeWire Pulse service."""

import json
import math
import os
import selectors
import signal
import subprocess
import sys
import time


def pactl(*arguments):
    result = subprocess.run(
        ["pactl", *arguments], capture_output=True, text=True, timeout=5, check=False
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "The audio service is unavailable")
    return result.stdout


def volume(item):
    channels = list(item.get("volume", {}).values())
    return (
        round(
            sum(channel["value"] / 65536 for channel in channels) / len(channels) * 100
        )
        if channels
        else None
    )


def device(item, default):
    ports = item.get("ports", [])
    active = next(
        (port for port in ports if port["name"] == item.get("active_port")), None
    )
    return {
        "id": item["index"],
        "serial": str(item.get("properties", {}).get("object.serial", item["index"])),
        "name": item["name"],
        "label": item.get("description") or item["name"],
        "volume": volume(item),
        "muted": item.get("mute", False),
        "default": item["name"] == default,
        "availability": active.get("availability", "unknown") if active else "unknown",
        "state": item.get("state", "unknown"),
        "ports": ports,
        "port": item.get("active_port", ""),
    }


def snapshot():
    info = json.loads(pactl("-f", "json", "info"))
    outputs = [
        device(item, info.get("default_sink_name"))
        for item in json.loads(pactl("-f", "json", "list", "sinks"))
    ]
    inputs = [
        device(item, info.get("default_source_name"))
        for item in json.loads(pactl("-f", "json", "list", "sources"))
        if not item.get("monitor_source")
        and item.get("properties", {}).get("device.class") != "monitor"
    ]
    streams = []
    for item in json.loads(pactl("-f", "json", "list", "sink-inputs")):
        properties = item.get("properties", {})
        streams.append(
            {
                "id": item["index"],
                "serial": str(properties.get("object.serial", item["index"])),
                "label": properties.get("application.name")
                or properties.get("media.name")
                or "Audio stream",
                "detail": properties.get("media.name", ""),
                "icon": properties.get("application.icon_name", ""),
                "volume": volume(item),
                "muted": item.get("mute", False),
                "sink": item.get("sink"),
                "writable": item.get("has_volume", True)
                and item.get("volume_writable", True),
            }
        )
    return {
        "outputs": outputs,
        "inputs": inputs,
        "streams": streams,
        "server": info.get("server_name", ""),
    }


def command(request):
    kinds = {"sink": "outputs", "source": "inputs", "sink-input": "streams"}
    kind = request.get("kind")
    if kind not in kinds:
        raise ValueError("Unsupported audio object")
    state = snapshot()
    node = next(
        (
            item
            for item in state[kinds[kind]]
            if item["id"] == request.get("id")
            and item["serial"] == request.get("serial")
        ),
        None,
    )
    if node is None:
        raise ValueError(
            "This audio device or stream disconnected; refresh before trying again"
        )
    action, value = request.get("action"), request.get("value")
    if action == "volume":
        if (
            type(value) not in (int, float)
            or not math.isfinite(value)
            or not 0 <= value <= 150
        ):
            raise ValueError("Volume must be between 0 and 150 percent")
        pactl("set-" + kind + "-volume", str(node["id"]), f"{value}%")
    elif action == "mute" and type(value) is bool:
        pactl("set-" + kind + "-mute", str(node["id"]), "1" if value else "0")
    elif action == "default" and kind in ("sink", "source"):
        pactl("set-default-" + kind, node["name"])
    elif action == "route" and kind == "sink-input":
        target = next((item for item in state["outputs"] if item["id"] == value), None)
        if target is None:
            raise ValueError("The selected output disconnected")
        pactl("move-sink-input", str(node["id"]), target["name"])
    elif action == "port" and kind in ("sink", "source"):
        if not any(
            port["name"] == value and port.get("availability") != "not available"
            for port in node["ports"]
        ):
            raise ValueError("The selected port is unavailable")
        pactl("set-" + kind + "-port", node["name"], value)
    else:
        raise ValueError("Unsupported audio action")


def emit(value):
    print(json.dumps(value), flush=True)


def watch():
    signal.signal(signal.SIGTERM, lambda number, frame: sys.exit(0))
    # Subscribe before the first snapshot so hotplug/default changes cannot fall in a gap.
    process = subprocess.Popen(
        ["pactl", "subscribe"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**os.environ, "LC_ALL": "C"},
    )
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            emit(snapshot())
            due = None
            buffered = b""
            while True:
                timeout = None if due is None else max(0, due - time.monotonic())
                for key, _ in selector.select(timeout):
                    data = os.read(key.fileobj.fileno(), 65536)
                    if not data:
                        raise RuntimeError(
                            "Audio subscription disconnected; reopen Audio to reconnect"
                        )
                    buffered += data
                    while b"\n" in buffered:
                        line, buffered = buffered.split(b"\n", 1)
                        if due is None and any(
                            b" on " + name + b" " in line
                            for name in (
                                b"sink",
                                b"source",
                                b"sink-input",
                                b"server",
                                b"card",
                            )
                        ):
                            due = time.monotonic() + 0.08
                if due is not None and time.monotonic() >= due:
                    emit(snapshot())
                    due = None
    finally:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["watch"]:
            watch()
        elif len(sys.argv) == 3 and sys.argv[1] == "command":
            command(json.loads(sys.argv[2]))
        elif sys.argv[1:] == ["snapshot"]:
            emit(snapshot())
        else:
            raise ValueError("Expected watch, snapshot, or command JSON")
    except (
        OSError,
        ValueError,
        KeyError,
        RuntimeError,
        subprocess.SubprocessError,
    ) as error:
        emit({"error": str(error)})
        sys.exit(1)
