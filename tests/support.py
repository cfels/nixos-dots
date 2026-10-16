import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


REPO = Path(__file__).resolve().parents[1]


class IsolatedDesktop:
    def __init__(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dots-tests-")
        self.root = Path(self.temporary.name)
        self.work = self.root / "work"
        self.home = self.root / "home/audituser"
        self.etc = self.root / "etc"
        self.repo = self.work / "repo"
        for path in (self.work / "bin", self.home, self.etc / "nixos"):
            path.mkdir(parents=True)
        shutil.copytree(REPO / "scripts", self.repo / "scripts")
        self.etc.joinpath("passwd").write_text(
            "root:x:0:0:root:/root:/bin/bash\n"
            "audituser:x:1000:1000:Audit:/home/audituser:/bin/bash\n"
        )
        self.etc.joinpath("group").write_text("root:x:0:\naudituser:x:1000:\n")
        self.etc.joinpath("os-release").write_text("ID=nixos\n")
        self.etc.joinpath("nixos/configuration.nix").write_text("{ original = true; }\n")
        self.etc.joinpath("nixos/hardware-configuration.nix").write_text("{}\n")
        for item in (".config", ".local", ".icons"):
            self.home.joinpath(item).mkdir()
            self.home.joinpath(item, "original").write_text(item)
        for package, path in (("config", ".config/example"), ("local", ".local/bin/example"), ("walls", "walls/example")):
            target = self.repo / "Configs" / package / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(package)
        shutil.copytree(REPO / "Configs/nixos", self.repo / "Configs/nixos")
        nvim = self.repo / "Configs/config/.config/nvim/init.lua"
        nvim.parent.mkdir(parents=True)
        nvim.write_text("")
        real_tools = {name: shutil.which(name) for name in ("cp", "mv", "diff", "mkdir", "mktemp", "ln", "stow", "chown")}
        mock = self.work / "bin/mock"
        mock.write_text(f"#!{sys.executable}\n" + "REAL = " + repr(real_tools) + "\n" + '''
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
if name == "sudo":
    if args and args[0] == "--":
        args = args[1:]
    if args and args[0] == "-u":
        user = args[1]
        args = args[2:]
        with open("/work/commands.jsonl", "a") as log:
            log.write(json.dumps(["run-as", user, *args]) + "\\n")
    name, *args = args
    if name == "NIXOS_INSTALL_BOOTLOADER=1":
        name, *args = args
    name = Path(name).name
with open("/work/commands.jsonl", "a") as log:
    log.write(json.dumps([name, *args]) + "\\n")
matched = os.environ.get("FAULT_MATCH", "") in " ".join(args)
fault = Path("/work/fault-used")
if name == os.environ.get("FAIL_COMMAND") and matched and not fault.exists():
    fault.touch()
    sys.exit(23)
if name == "nixos-rebuild":
    Path("/work/activated-config").write_text(Path("/etc/nixos/configuration.nix").read_text())
    if os.environ.get("CREATE_USER"):
        user = os.environ["CREATE_USER"]
        with open("/etc/passwd", "a") as passwd:
            passwd.write(f"{user}:x:1001:1000:New:/home/{user}:/bin/bash\\n")
    sys.exit(int(os.environ.get("REBUILD_STATUS", "0")))
if name == "switch-to-configuration":
    sys.exit(int(os.environ.get("DIRECT_ACTIVATION_STATUS", "0")))
if name == "chown":
    args[args.index("--") + 1] = "0"
    sys.exit(subprocess.run([REAL[name], *args], check=False).returncode)
if name in {"fc-cache", "git"}:
    sys.exit(0)
if name == "nixos-generate-config":
    print("{}")
    sys.exit(0)
if name == "findmnt":
    sys.exit(0)
if name not in REAL or not REAL[name]:
    sys.exit("unmocked privileged command: " + name)
result = subprocess.run([REAL[name], *args], check=False)
if name == os.environ.get("SIGNAL_COMMAND") and matched and not fault.exists():
    fault.touch()
    os.kill(os.getppid(), getattr(signal, os.environ.get("TEST_SIGNAL", "SIGTERM")))
sys.exit(result.returncode)
''')
        mock.chmod(0o755)
        for name in ("sudo", "stow", "nixos-rebuild", "fc-cache", "git", "nixos-generate-config", "findmnt"):
            (self.work / "bin" / name).symlink_to("mock")

    def command(self, script, *arguments, **environment):
        bwrap = shutil.which("bwrap")
        if not bwrap:
            raise RuntimeError("bubblewrap is required; installer tests must not run without isolation")
        settings = {
            "PATH": "/work/bin:/run/current-system/sw/bin:/usr/bin:/bin",
            "HOME": "/home/audituser",
            "DOTS_USER": "audituser",
            **environment,
        }
        command = [
            bwrap, "--unshare-all", "--die-with-parent", "--uid", "0", "--gid", "0",
            "--tmpfs", "/", "--ro-bind", "/nix/store", "/nix/store",
            "--ro-bind", "/bin", "/bin", "--ro-bind", "/usr", "/usr",
            "--proc", "/proc", "--dev", "/dev",
            "--tmpfs", "/tmp", "--tmpfs", "/run",
            "--ro-bind", str(Path("/run/current-system").resolve()), "/run/current-system",
            "--bind", str(self.work), "/work", "--bind", str(self.root / "home"), "/home",
            "--bind", str(self.etc), "/etc", "--tmpfs", "/root",
            "--chdir", "/work/repo", "--clearenv",
        ]
        for key, value in settings.items():
            command.extend(("--setenv", key, str(value)))
        command.extend((
            "--", "/run/current-system/sw/bin/bash", "-c",
            'printf "dots-test-ready\\n"; exec bash "$@"', "test", script, *arguments,
        ))
        return command

    def run(self, script, *arguments, **environment):
        result = subprocess.run(self.command(script, *arguments, **environment), capture_output=True, text=True, timeout=30)
        if not result.stdout.startswith("dots-test-ready\n"):
            raise RuntimeError("test isolation did not start: " + result.stderr)
        result.stdout = result.stdout.removeprefix("dots-test-ready\n")
        return result

    def commands(self):
        path = self.work / "commands.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def close(self):
        self.temporary.cleanup()
