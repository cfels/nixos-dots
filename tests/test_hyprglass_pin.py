import json
import shutil
import sys
import unittest

from support import IsolatedDesktop


class HyprglassPinTests(unittest.TestCase):
    def setUp(self):
        self.desktop = IsolatedDesktop()
        self.addCleanup(self.desktop.close)
        shutil.copytree(self.desktop.repo / "Configs/nixos", self.desktop.etc / "nixos", dirs_exist_ok=True)
        (self.desktop.etc / "nixos/username.nix").write_text('"audituser"\n')
        nix = self.desktop.work / "bin/nix"
        nix.write_text(f"#!{sys.executable}\n" + '''
import json
from pathlib import Path
import sys

args = sys.argv[1:]
with open("/work/nix-commands.jsonl", "a") as log:
    log.write(json.dumps(args) + "\\n")
if args == ["eval", "--raw", "--file", "/etc/nixos/username.nix"]:
    print("audituser")
elif args == ["eval", "--raw", '/etc/nixos#nixosConfigurations."audituser".pkgs.hyprland.version']:
    print("0.55.0")
elif args == ["flake", "update", "--flake", "/etc/nixos", "hyprglass"]:
    pass
else:
    sys.exit("unexpected nix command: " + repr(args))
''')
        nix.chmod(0o755)
        curl = self.desktop.work / "bin/curl"
        curl.write_text('#!/usr/bin/env bash\ncat /work/hyprpm.toml\n')
        curl.chmod(0o755)

    def run_pin(self, upstream):
        (self.desktop.work / "hyprpm.toml").write_text(upstream)
        return self.desktop.run("/work/repo/Configs/nixos/scripts/hyprglass-pin.sh")

    def test_configured_user_is_used_and_missing_pin_changes_nothing(self):
        source = self.desktop.etc / "nixos/flake.nix"
        before = source.read_bytes()
        result = self.run_pin("")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(source.read_bytes(), before)
        self.assertIn("keeping current pin", result.stderr)

    def test_matching_pin_preserves_existing_update_commands(self):
        revision = "b" * 40
        result = self.run_pin(f'["{"a" * 40}", "{revision}"], # hyprland 0.55.0 -> hyprglass v0.10.1\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("github:hyprnux/hyprglass/" + revision, (self.desktop.etc / "nixos/flake.nix").read_text())
        self.assertIn('version = "0.10.1";', (self.desktop.etc / "nixos/packages/hyprglass.nix").read_text())
        commands = [json.loads(line) for line in (self.desktop.work / "nix-commands.jsonl").read_text().splitlines()]
        self.assertEqual(commands[-1], ["flake", "update", "--flake", "/etc/nixos", "hyprglass"])
