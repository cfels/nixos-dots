import shutil
import unittest

from support import REPO, IsolatedDesktop


@unittest.skipUnless(
    all(shutil.which(tool) for tool in ("pulseaudio", "pactl", "pacat")),
    "Private audio test tools are required",
)
class SettingsAudioTests(unittest.TestCase):
    def test_devices_streams_routing_and_external_changes(self):
        desktop = IsolatedDesktop()
        self.addCleanup(desktop.close)
        shutil.copy2(
            REPO / "Configs/config/.config/hypr/scripts/moxi-audio.py",
            desktop.work / "moxi-audio.py",
        )
        shutil.copy2(
            REPO / "tests/audio_settings_scenario.py",
            desktop.work / "audio-scenario.py",
        )
        (desktop.work / "audio.sh").write_text("""set -euo pipefail
mkdir -p /tmp/runtime
chmod 700 /tmp/runtime
pulseaudio -n --daemonize=no --use-pid-file=no --exit-idle-time=-1 \
  --load='module-native-protocol-unix socket=/tmp/settings-pulse auth-anonymous=1' >/work/pulse.log 2>&1 &
server=$!
trap 'kill "$server"; wait "$server" || true' EXIT
for attempt in {1..100}; do
  [[ -S /tmp/settings-pulse ]] && break
  sleep 0.02
done
python3 -B /work/audio-scenario.py
""")
        result = desktop.run(
            "/work/audio.sh",
            XDG_RUNTIME_DIR="/tmp/runtime",
            PULSE_SERVER="unix:/tmp/settings-pulse",
            DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/no-bus",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("AUDIO_SETTINGS_OK", result.stdout)
