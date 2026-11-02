import os
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

LAUNCHER = os.environ.get("DOTS_HELIUM_LAUNCHER")


@unittest.skipUnless(LAUNCHER, "Set DOTS_HELIUM_LAUNCHER to the built Helium launcher")
class HeliumTests(unittest.TestCase):
    def setUp(self):
        self.runtime = Path(os.environ["XDG_RUNTIME_DIR"])
        self.temporary = tempfile.TemporaryDirectory(
            prefix="helium-test-", dir=self.runtime
        )
        self.addCleanup(self.temporary.cleanup)
        # Exercise literal argument forwarding through systemd as well as the shell.
        self.profile = Path(self.temporary.name) / "profile $HOME%20"
        self.arguments = [
            f"--user-data-dir={self.profile}",
            "--ozone-platform=headless",
            "--disable-gpu",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-background-networking",
            "--disable-component-update",
            "about:blank",
        ]
        self.browser_pid = None
        self.log = Path(self.temporary.name).joinpath("launcher.log").open("w+")
        self.addCleanup(self.log.close)
        self.opener = subprocess.Popen(
            self.command(isolated=True),
            stdout=self.log,
            stderr=self.log,
        )
        self.addCleanup(self.stop_browser)
        deadline = time.monotonic() + 15
        while not self.socket.exists():
            if self.opener.poll() is not None or time.monotonic() >= deadline:
                self.log.seek(0)
                self.fail(
                    "Helium did not create its handoff socket: " + self.log.read()
                )
            time.sleep(0.1)
        self.lock = os.readlink(self.profile / "SingletonLock")
        self.browser_pid = int(self.lock.rsplit("-", 1)[1])

    @property
    def socket(self):
        return self.profile / "SingletonSocket"

    def command(self, *, isolated=False):
        command = [LAUNCHER, *self.arguments]
        if isolated:
            bwrap = shutil.which("bwrap")
            if not bwrap:
                self.fail("Bubblewrap is required for the isolated launcher check")
            command = [
                bwrap,
                "--die-with-parent",
                "--bind",
                "/",
                "/",
                "--tmpfs",
                "/tmp",
                "--unshare-pid",
                "--proc",
                "/proc",
                "--setenv",
                "TMPDIR",
                "/tmp/missing-launcher-directory",
                "--setenv",
                "XDG_CONFIG_HOME",
                "/tmp/launcher-config",
                "--",
                *command,
            ]
        return command

    def stop_browser(self):
        if self.browser_pid is not None:
            cmdline = Path(f"/proc/{self.browser_pid}/cmdline")
            if cmdline.exists():
                self.assertIn(os.fsencode(self.arguments[0]), cmdline.read_bytes())
                os.kill(self.browser_pid, signal.SIGTERM)
                deadline = time.monotonic() + 10
                while cmdline.exists() and time.monotonic() < deadline:
                    time.sleep(0.1)
                self.assertFalse(
                    cmdline.exists(), "The disposable browser did not stop"
                )
        if self.opener.poll() is None:
            self.opener.terminate()
        self.opener.wait(timeout=10)

    def test_handoff_survives_opener_exit_and_private_namespaces(self):
        socket_path = Path(os.readlink(self.socket))
        self.assertTrue(socket_path.is_relative_to(self.runtime / "helium"))
        self.assertTrue(socket_path.exists())

        # A launcher closing must not take the browser or its socket with it.
        self.opener.kill()
        self.opener.wait(timeout=10)
        self.assertTrue(self.socket.exists())

        for isolated in (False, True, True):
            with self.subTest(isolated=isolated):
                result = subprocess.run(
                    self.command(isolated=isolated),
                    capture_output=True,
                    check=False,
                    text=True,
                    timeout=15,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(os.readlink(self.profile / "SingletonLock"), self.lock)
                self.assertEqual(Path(os.readlink(self.socket)), socket_path)
                self.assertTrue(self.socket.exists())
