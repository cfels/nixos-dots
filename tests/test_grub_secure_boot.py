"""Secure Boot regression tests; no host firmware or signing keys are modified."""

import importlib.util
from pathlib import Path
import tempfile
import shutil
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "snapshot", Path(__file__).parents[1] / "Configs/nixos/scripts/grub-secure-snapshot.py")
snapshot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(snapshot)

setup_spec = importlib.util.spec_from_file_location(
    "setup", Path(__file__).parents[1] / "Configs/nixos/scripts/grub-secure-setup.py")
setup = importlib.util.module_from_spec(setup_spec)
setup_spec.loader.exec_module(setup)

CONFIG = """search --set=drive1 --fs-uuid 9D68-F9F1
if [ -s $prefix/grubenv ]; then
  load_env
fi
set timeout=0
if [ -z "$chosen" ]; then
  configfile $prefix/$config_file
fi
menuentry 'NixOS' {
  search --set=drive1 --fs-uuid 9D68-F9F1
  linux ($drive1)//kernels/linux init=/nix/store/example/init quiet
  initrd ($drive1)//kernels/initrd
}
"""
MAINMENU = """set timeout=0
menuentry 'Singlebooter' {
  configfile $prefix/grub.cfg
}
"""


class SnapshotTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.boot = self.root / "boot"
        self.stage = self.root / "stage"
        (self.boot / "grub/themes/minegrub").mkdir(parents=True)
        (self.boot / "kernels").mkdir()
        (self.boot / "grub/grub.cfg").write_text(CONFIG)
        (self.boot / "grub/mainmenu.cfg").write_text(MAINMENU)
        (self.boot / "kernels/linux").write_bytes(b"embedded kernel")
        (self.boot / "kernels/initrd").write_bytes(b"embedded initrd")
        (self.boot / "grub/themes/minegrub/theme.txt").write_text("desktop-color: black")

    def test_snapshot_is_independent_of_disk_files_and_grubenv(self):
        (self.boot / "grub/grubenv").write_text("config_file=evil.cfg")
        snapshot.prepare_snapshot(self.boot, self.stage)
        config = (self.stage / "boot/grub/grub.cfg").read_text()
        self.assertNotIn("search --set", config)
        self.assertNotIn("load_env", config)
        self.assertIn("set root=memdisk", config)
        self.assertIn("set config_file=mainmenu.cfg", config)
        self.assertFalse((self.stage / "boot/grub/grubenv").exists())
        (self.boot / "kernels/linux").write_bytes(b"tampered after snapshot")
        self.assertEqual((self.stage / "kernels/linux").read_bytes(), b"embedded kernel")

    def test_external_or_traversing_kernel_is_rejected(self):
        for path in ["(hd0,gpt1)/vmlinuz", "($drive1)//kernels/../../evil"]:
            with self.subTest(path=path):
                (self.boot / "grub/grub.cfg").write_text(
                    CONFIG.replace("($drive1)//kernels/linux", path))
                with self.assertRaises(ValueError):
                    snapshot.prepare_snapshot(self.boot, self.stage)

    def test_external_chainloader_in_either_menu_is_rejected(self):
        for menu in ["grub.cfg", "mainmenu.cfg"]:
            with self.subTest(menu=menu):
                path = self.boot / "grub" / menu
                original = path.read_text()
                path.write_text(original + "\nchainloader (hd0,gpt1)/unsigned.efi\n")
                with self.assertRaises(ValueError):
                    snapshot.prepare_snapshot(self.boot, self.stage)
                path.write_text(original)

    def test_changed_grubenv_loader_is_rejected(self):
        (self.boot / "grub/grub.cfg").write_text(CONFIG.replace("load_env", "load_env -f /evil"))
        with self.assertRaises(ValueError):
            snapshot.prepare_snapshot(self.boot, self.stage)

    def test_both_menus_can_boot_with_cli_disabled(self):
        snapshot.prepare_snapshot(self.boot, self.stage)
        for menu in ["grub.cfg", "mainmenu.cfg"]:
            config = (self.stage / "boot/grub" / menu).read_text()
            self.assertIn("--unrestricted {", config)

    def test_external_config_and_path_overrides_are_rejected(self):
        for command in ["configfile /evil.cfg", "set prefix=(hd0)/grub",
                        "load_env -f /evil", "cat (hd0)/evil"]:
            with self.subTest(command=command):
                (self.boot / "grub/grub.cfg").write_text(CONFIG + "\n" + command + "\n")
                with self.assertRaises(ValueError):
                    snapshot.prepare_snapshot(self.boot, self.stage)

    def test_kernels_are_signed_without_modifying_initrd_or_original_files(self):
        kernels = snapshot.prepare_snapshot(self.boot, self.stage)

        def fake_sign(source, destination, key, cert):
            destination.write_bytes(source.read_bytes() + b" signature")

        with patch.object(snapshot, "sign_image", side_effect=fake_sign) as signer:
            snapshot.sign_kernels(kernels, Path("db.key"), Path("db.pem"))
        self.assertEqual(signer.call_count, 1)
        self.assertEqual((self.stage / "kernels/linux").read_bytes(), b"embedded kernel signature")
        self.assertEqual((self.stage / "kernels/initrd").read_bytes(), b"embedded initrd")
        self.assertEqual((self.boot / "kernels/linux").read_bytes(), b"embedded kernel")

    def test_failed_kernel_signing_does_not_replace_kernel(self):
        kernels = snapshot.prepare_snapshot(self.boot, self.stage)
        with patch.object(snapshot, "sign_image", side_effect=RuntimeError("verification failed")):
            with self.assertRaises(RuntimeError):
                snapshot.sign_kernels(kernels, Path("db.key"), Path("db.pem"))
        self.assertEqual((self.stage / "kernels/linux").read_bytes(), b"embedded kernel")

    def test_plain_grub_without_minegrub_is_supported(self):
        (self.boot / "grub/mainmenu.cfg").unlink()
        shutil.rmtree(self.boot / "grub/themes")
        (self.boot / "grub/grub.cfg").write_text(CONFIG.replace(
            'if [ -z "$chosen" ]; then\n  configfile $prefix/$config_file\nfi\n', ""))
        kernels = snapshot.prepare_snapshot(self.boot, self.stage)
        self.assertEqual(len(kernels), 1)
        self.assertFalse((self.stage / "boot/grub/mainmenu.cfg").exists())
        self.assertNotIn("config_file=mainmenu", (self.stage / "boot/grub/grub.cfg").read_text())


class SetupTests(unittest.TestCase):
    PARTUUID = "12345678-1234-1234-1234-123456789abc"

    def test_nvme_and_sata_efi_partitions_are_detected(self):
        for disk, part in [("/dev/nvme1n1", 3), ("/dev/sdb", 1)]:
            source = disk + ("p" if "nvme" in disk else "") + str(part)
            with self.subTest(disk=disk), patch.object(setup.os.path, "ismount", return_value=True), \
                    patch.object(setup, "read_json", side_effect=[
                        {"filesystems": [{"source": source, "fstype": "vfat"}]},
                        {"blockdevices": [{"type": "part", "pkname": disk, "partn": part,
                          "partuuid": self.PARTUUID,
                          "parttype": "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"}]},
                    ]):
                self.assertEqual(setup.detect_esp(Path("/efi")), (disk, part, self.PARTUUID))

    def test_unmounted_efi_partition_is_rejected(self):
        with patch.object(setup.os.path, "ismount", return_value=False):
            with self.assertRaises(ValueError):
                setup.detect_esp(Path("/boot"))

    def test_entry_matching_checks_partition_and_loader_not_label(self):
        entries = (f"Boot0001* Same label HD(1,GPT,{self.PARTUUID},0,1)/\\EFI\\other.efi\n"
                   f"Boot000A* Different label HD(3,GPT,{self.PARTUUID},0,1)/{setup.LOADER}\n")
        self.assertEqual(setup.find_entry(entries, 3, self.PARTUUID), "000A")
        self.assertIsNone(setup.find_entry(entries, 2, self.PARTUUID))
        self.assertIsNone(setup.find_entry(entries, 3, "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))

    def test_partial_keys_are_never_replaced(self):
        with tempfile.TemporaryDirectory() as temporary:
            pki = Path(temporary)
            key = pki / "keys/db/db.key"
            key.parent.mkdir(parents=True)
            key.write_text("existing private key")
            with patch.object(setup.subprocess, "run") as run:
                with self.assertRaises(ValueError):
                    setup.ensure_keys(pki)
                run.assert_not_called()
            self.assertEqual(key.read_text(), "existing private key")

    def test_existing_keys_are_reused(self):
        with tempfile.TemporaryDirectory() as temporary:
            pki = Path(temporary)
            for name in ["PK", "KEK", "db"]:
                directory = pki / "keys" / name
                directory.mkdir(parents=True)
                for suffix in [".key", ".pem"]:
                    (directory / (name + suffix)).write_text("existing key")
            (pki / "GUID").write_text("existing owner")
            with patch.object(setup.subprocess, "run") as run:
                setup.ensure_keys(pki)
                run.assert_not_called()

    def test_missing_keys_are_not_regenerated_under_secure_boot(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(setup.subprocess, "run") as run:
            with self.assertRaisesRegex(ValueError, "Secure Boot is enabled"):
                setup.ensure_keys(Path(temporary), allow_create=False)
            run.assert_not_called()

    def test_setup_reuses_entry_without_enrolling_or_reordering(self):
        entries = ("BootCurrent: 0006\n"
                   f"Boot0006* NixOS Secure GRUB HD(1,GPT,{self.PARTUUID},0,1)/{setup.LOADER}\n")
        with patch.object(setup, "read_json", return_value={"secure_boot": True, "setup_mode": False}), \
                patch.object(setup, "detect_esp", return_value=("/dev/sdb", 1, self.PARTUUID)), \
                patch.object(setup, "ensure_keys"), \
                patch.object(setup.subprocess, "check_output", return_value=entries), \
                patch.object(setup.subprocess, "run") as run, patch("builtins.print"):
            setup.prepare(Path("/efi"), Path("/custom-pki"))
        run.assert_called_once_with(["grub-secure-snapshot", "--boot", "/efi", "--pki", "/custom-pki"], check=True)

    def test_new_entry_is_created_without_changing_boot_order(self):
        created = f"Boot000B* NixOS Secure GRUB HD(2,GPT,{self.PARTUUID},0,1)/{setup.LOADER}\n"
        with patch.object(setup, "read_json", return_value={"secure_boot": False, "setup_mode": True}), \
                patch.object(setup, "detect_esp", return_value=("/dev/nvme1n1", 2, self.PARTUUID)), \
                patch.object(setup, "ensure_keys"), \
                patch.object(setup.subprocess, "check_output", side_effect=["BootOrder: 0000\n", created]), \
                patch.object(setup.subprocess, "run") as run, patch("builtins.print"):
            setup.prepare(Path("/boot"), Path("/var/lib/sbctl"))
        self.assertEqual(run.call_count, 2)
        self.assertEqual(run.call_args.args[0], ["efibootmgr", "--create-only", "--disk", "/dev/nvme1n1",
                         "--part", "2", "--label", setup.LABEL, "--loader", setup.LOADER])


if __name__ == "__main__":
    unittest.main()
