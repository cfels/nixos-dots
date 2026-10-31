import json
import shutil
import sys
import unittest

from support import IsolatedDesktop, REPO


class HyprglassPinTests(unittest.TestCase):
    def setUp(self):
        self.desktop = IsolatedDesktop()
        self.addCleanup(self.desktop.close)
        shutil.copytree(self.desktop.repo / "Configs/nixos", self.desktop.etc / "nixos", dirs_exist_ok=True)
        (self.desktop.etc / "nixos/username.nix").write_text('"audituser"\n')
        nix = self.desktop.work / "bin/nix"
        nix.write_text(f"#!{sys.executable}\n" + '''
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with open("/work/nix-commands.jsonl", "a") as log:
    log.write(json.dumps(args) + "\\n")
if args == ["eval", "--raw", "--file", "/etc/nixos/username.nix"]:
    print("audituser")
elif args == ["eval", "--raw", "--file", "/work/repo/Configs/nixos/username.nix"]:
    print("audituser")
elif len(args) in (4, 5) and args[:3] == ["flake", "update", "--flake"]:
    if len(args) == 5:
        assert args[4] == "hyprglass", args
        sys.exit(int(os.environ.get("NIX_PIN_STATUS", "0")))
    sys.exit(int(os.environ.get("NIX_UPDATE_STATUS", "0")))
else:
    sys.exit("unexpected nix command: " + repr(args))
''')
        nix.chmod(0o755)
        curl = self.desktop.work / "bin/curl"
        curl.write_text(f"#!{sys.executable}\n" + '''
import os
from pathlib import Path
import sys

url = sys.argv[-1]
with open("/work/curl-commands.log", "a") as log:
    log.write(url + "\\n")
status = int(os.environ.get("CURL_STATUS", "0"))
if status:
    sys.exit(status)
if url == "https://api.github.com/repos/hyprnux/hyprglass/releases/latest":
    print(Path("/work/release.json").read_text())
elif url.startswith("https://api.github.com/repos/hyprnux/hyprglass/commits/"):
    print(Path("/work/commit.json").read_text())
else:
    sys.exit("unexpected curl URL: " + url)
''')
        curl.chmod(0o755)
        self.release()

    def release(self, tag="v2.0.0", revision="b" * 40):
        (self.desktop.work / "release.json").write_text(json.dumps({"tag_name": tag}))
        (self.desktop.work / "commit.json").write_text(json.dumps({"sha": revision}))

    def run_pin(self, *arguments, **environment):
        return self.desktop.run("/work/repo/Configs/nixos/scripts/hyprglass-pin.sh", *arguments, **environment)

    def nix_commands(self):
        path = self.desktop.work / "nix-commands.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_latest_release_is_used_without_a_hyprpm_pin(self):
        result = self.run_pin()
        self.assertEqual(result.returncode, 0, result.stderr)
        flake = self.desktop.etc / "nixos"
        self.assertIn("github:hyprnux/hyprglass/" + "b" * 40, (flake / "flake.nix").read_text())
        self.assertIn('version = "2.0.0";', (flake / "packages/hyprglass.nix").read_text())
        self.assertEqual(self.nix_commands(), [["flake", "update", "--flake", "/etc/nixos", "hyprglass"]])
        self.assertEqual((self.desktop.work / "curl-commands.log").read_text().splitlines(), [
            "https://api.github.com/repos/hyprnux/hyprglass/releases/latest",
            "https://api.github.com/repos/hyprnux/hyprglass/commits/v2.0.0",
        ])

    def test_explicit_flake_path_changes_only_that_flake(self):
        default = self.desktop.etc / "nixos/flake.nix"
        before = default.read_bytes()
        result = self.run_pin("/work/repo/Configs/nixos")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(default.read_bytes(), before)
        self.assertIn("github:hyprnux/hyprglass/" + "b" * 40, (self.desktop.repo / "Configs/nixos/flake.nix").read_text())
        self.assertEqual(self.nix_commands(), [["flake", "update", "--flake", "/work/repo/Configs/nixos", "hyprglass"]])

    def test_unchanged_pin_refreshes_lock_after_an_interrupted_update(self):
        first = self.run_pin(NIX_PIN_STATUS=23)
        self.assertEqual(first.returncode, 23, first.stderr)
        second = self.run_pin()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(len(self.nix_commands()), 2)

    def test_invalid_release_data_changes_nothing(self):
        flake = self.desktop.etc / "nixos"
        before = [(flake / name).read_bytes() for name in ("flake.nix", "packages/hyprglass.nix")]
        for tag, revision in ((None, "b" * 40), ("main", "b" * 40), ("v2.0.0-rc1", "b" * 40),
                              ("v2.0.0", None), ("v2.0.0", "main")):
            with self.subTest(tag=tag, revision=revision):
                self.release(tag, revision)
                result = self.run_pin()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual([(flake / name).read_bytes() for name in ("flake.nix", "packages/hyprglass.nix")], before)
                self.assertEqual(self.nix_commands(), [])

    def test_network_failure_changes_nothing(self):
        source = self.desktop.etc / "nixos/flake.nix"
        before = source.read_bytes()
        result = self.run_pin(CURL_STATUS=22)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(source.read_bytes(), before)
        self.assertEqual(self.nix_commands(), [])

    @unittest.skipUnless(shutil.which("fish"), "Fish is required for shell function verification")
    def test_nixupdate_uses_user_cache_and_only_repins_after_success(self):
        shutil.copyfile(REPO / "Configs/config/.config/fish/config.fish", self.desktop.work / "config.fish")
        doas = self.desktop.work / "bin/doas"
        doas.write_text('#!/usr/bin/env bash\necho "unexpected privilege elevation" >&2\nexit 99\n')
        doas.chmod(0o755)
        fish_script = self.desktop.work / "update.fish"
        fish_script.write_text('''
function starship
end
function fastfetch
end
function funcsave
end
source /work/config.fish
nixupdate
''')
        launcher = self.desktop.work / "update.sh"
        launcher.write_text('exec fish --no-config /work/update.fish\n')
        for status, curl_status in ((0, 0), (23, 0), (0, 22)):
            with self.subTest(status=status, curl_status=curl_status):
                log = self.desktop.work / "nix-commands.jsonl"
                log.unlink(missing_ok=True)
                result = self.desktop.run("/work/update.sh", NIX_UPDATE_STATUS=status, CURL_STATUS=curl_status)
                if curl_status:
                    self.assertNotEqual(result.returncode, 0)
                else:
                    self.assertEqual(result.returncode, status, result.stderr)
                commands = self.nix_commands()
                self.assertEqual(commands[0], ["flake", "update", "--flake", "/etc/nixos"])
                self.assertEqual(len(commands), 2 if status == curl_status == 0 else 1)

    def test_graphical_updater_refreshes_hyprglass_before_rebuild(self):
        gum = self.desktop.work / "bin/gum"
        gum.write_text('''#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == spin ]]; then
  while [[ "$1" != -- ]]; do shift; done
  shift
  exec "$@"
fi
''')
        gum.chmod(0o755)
        clear = self.desktop.work / "bin/clear"
        clear.write_text('#!/usr/bin/env bash\nexit 0\n')
        clear.chmod(0o755)
        doas = self.desktop.work / "bin/doas"
        doas.write_text('''#!/usr/bin/env bash
set -euo pipefail
cat /work/repo/Configs/nixos/flake.nix > /work/rebuilt-flake.nix
printf '%s\\n' "$@" > /work/rebuild-args
''')
        doas.chmod(0o755)
        driver = self.desktop.work / "updater-tty.py"
        driver.write_text('''import errno
import os
import pty
import subprocess
import sys

master, slave = pty.openpty()
process = subprocess.Popen(["bash", "/work/repo/scripts/updater/update.sh"], stdin=slave, stdout=slave, stderr=slave)
os.close(slave)
os.write(master, b"x")
try:
    while True:
        try:
            output = os.read(master, 65536)
        except OSError as error:
            if error.errno == errno.EIO:
                break
            raise
        if not output:
            break
        sys.stdout.buffer.write(output)
finally:
    os.close(master)
sys.exit(process.wait(timeout=5))
''')
        launcher = self.desktop.work / "updater-tty.sh"
        launcher.write_text('exec python3 /work/updater-tty.py\n')
        for update_status, curl_status, pin_status in ((0, 0, 0), (23, 0, 0), (0, 22, 0), (0, 0, 23)):
            with self.subTest(update_status=update_status, curl_status=curl_status, pin_status=pin_status):
                snapshot = self.desktop.work / "rebuilt-flake.nix"
                snapshot.unlink(missing_ok=True)
                (self.desktop.work / "nix-commands.jsonl").unlink(missing_ok=True)
                (self.desktop.work / "curl-commands.log").unlink(missing_ok=True)
                result = self.desktop.run("/work/updater-tty.sh", NIX_UPDATE_STATUS=update_status,
                                          CURL_STATUS=curl_status, NIX_PIN_STATUS=pin_status)
                commands = self.nix_commands()
                self.assertEqual(commands[1], ["flake", "update", "--flake", "/work/repo/Configs/nixos"])
                if update_status or curl_status or pin_status:
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertFalse(snapshot.exists())
                    if update_status:
                        self.assertFalse((self.desktop.work / "curl-commands.log").exists())
                else:
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn("github:hyprnux/hyprglass/" + "b" * 40, snapshot.read_text())
                    self.assertEqual(commands[-1], ["flake", "update", "--flake", "/work/repo/Configs/nixos", "hyprglass"])
                    self.assertIn("/work/repo/Configs/nixos#audituser", (self.desktop.work / "rebuild-args").read_text())
