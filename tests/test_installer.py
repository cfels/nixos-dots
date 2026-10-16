import shutil
import sys
import unittest

from support import IsolatedDesktop


BACKUP = "/work/repo/scripts/installer/just_to_be_safe/backup.sh"
RESTORE = "/work/repo/scripts/installer/just_to_be_safe/restore.sh"
APPLY = "/work/repo/scripts/installer/applyconfigs_stow.sh"
MAIN = "/work/repo/scripts/installer/main.sh"


class InstallerTestCase(unittest.TestCase):
    def setUp(self):
        self.desktop = IsolatedDesktop()
        self.addCleanup(self.desktop.close)

    def backup(self, **environment):
        result = self.desktop.run(BACKUP, **environment)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return self.desktop.home / "dots-backup"


class BackupTests(InstallerTestCase):
    def test_concurrent_operation_is_rejected(self):
        script = self.desktop.work / "hold-lock.sh"
        script.write_text('''
source /work/repo/scripts/installer/common.sh
dots_resolve_user
dots_lock
DOTS_LOCK_USER= bash /work/repo/scripts/installer/just_to_be_safe/backup.sh 9>&-
''')
        result = self.desktop.run("/work/hold-lock.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("another installer operation", result.stderr)
        self.assertFalse((self.desktop.home / "dots-backup").exists())

    def test_complete_backup_does_not_move_live_configuration(self):
        backup = self.backup()
        self.assertEqual((backup / ".config/original").read_text(), ".config")
        self.assertTrue((self.desktop.etc / "nixos/configuration.nix").is_file())
        self.assertFalse((self.desktop.etc / "nixos.bak").exists())
        self.assertIn(".icons\tpresent", (backup / ".dots-manifest").read_text())

    def test_failed_copy_preserves_previous_backup_and_live_files(self):
        backup = self.backup()
        (self.desktop.home / ".config/original").write_text("new config")
        result = self.desktop.run(BACKUP, FAIL_COMMAND="cp", FAULT_MATCH=".local/.")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((backup / ".config/original").read_text(), ".config")
        self.assertEqual((self.desktop.home / ".config/original").read_text(), "new config")
        self.assertTrue((self.desktop.etc / "nixos").is_dir())

    def test_failed_verification_does_not_publish(self):
        result = self.desktop.run(BACKUP, FAIL_COMMAND="diff", FAULT_MATCH=".config/.")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.desktop.home / "dots-backup").exists())

    def test_repeated_backup_preserves_original_system_and_previous_snapshot(self):
        backup = self.backup()
        (self.desktop.etc / "nixos/configuration.nix").write_text("changed system")
        (self.desktop.home / ".config/original").write_text("changed config")
        self.backup()
        self.assertEqual((backup / "nixos/configuration.nix").read_text(), "{ original = true; }\n")
        previous = list(self.desktop.home.glob(".dots-backup.*"))
        self.assertEqual(len(previous), 1)
        self.assertEqual((previous[0] / ".config/original").read_text(), ".config")

    def test_missing_optional_directories_are_recorded(self):
        shutil.rmtree(self.desktop.home / ".icons")
        backup = self.backup()
        self.assertIn(".icons\tabsent", (backup / ".dots-manifest").read_text())

    def test_top_level_source_symlink_is_materialized(self):
        source = self.desktop.work / "external-config"
        shutil.move(self.desktop.home / ".config", source)
        (self.desktop.home / ".config").symlink_to("/work/external-config")
        backup = self.backup()
        self.assertFalse((backup / ".config").is_symlink())
        self.assertEqual((backup / ".config/original").read_text(), ".config")

    def test_invalid_user_is_rejected_before_privileged_operations(self):
        for username in ("../audituser", ".", "..", "root", "--help"):
            with self.subTest(username=username):
                result = self.desktop.run(BACKUP, DOTS_USER=username)
                self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.desktop.commands(), [])

    def test_unsafe_home_is_rejected_before_privileged_operations(self):
        passwd = self.desktop.etc / "passwd"
        passwd.write_text(passwd.read_text().replace("/home/audituser", "/etc"))
        result = self.desktop.run(BACKUP)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.desktop.commands(), [])

    def test_linked_home_is_rejected(self):
        self.desktop.home.rename(self.desktop.home.with_name("actual-home"))
        self.desktop.home.symlink_to("/home/actual-home")
        result = self.desktop.run(BACKUP)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must not traverse symlinks", result.stderr)
        self.assertEqual(self.desktop.commands(), [])

    def test_symlinks_inside_a_snapshot_are_preserved_without_dereferencing(self):
        (self.desktop.home / ".config/reference").symlink_to("/work/personal-file")
        (self.desktop.work / "personal-file").write_text("outside config")
        backup = self.backup()
        self.assertTrue((backup / ".config/reference").is_symlink())
        self.assertEqual((self.desktop.work / "personal-file").read_text(), "outside config")

    def test_linked_backup_is_rejected(self):
        (self.desktop.home / "dots-backup").symlink_to("/etc/nixos")
        result = self.desktop.run(BACKUP)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.desktop.etc / "nixos/configuration.nix").exists())

    def test_empty_system_directory_is_not_a_valid_backup(self):
        for path in (self.desktop.etc / "nixos").iterdir():
            path.unlink()
        result = self.desktop.run(BACKUP)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.desktop.home / "dots-backup").exists())

    def test_account_lookup_failure_is_not_treated_as_a_new_user(self):
        getent = self.desktop.work / "bin/getent"
        getent.write_text("#!/usr/bin/env bash\nexit 1\n")
        getent.chmod(0o755)
        result = self.desktop.run(BACKUP)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("could not resolve account", result.stderr)
        self.assertEqual(self.desktop.commands(), [])


class RestoreTests(InstallerTestCase):
    def change_live_files(self):
        for item in (".config", ".local", ".icons"):
            (self.desktop.home / item / "original").write_text("live")
        (self.desktop.etc / "nixos/configuration.nix").write_text("live system")

    def assert_live_files(self):
        for item in (".config", ".local", ".icons"):
            self.assertEqual((self.desktop.home / item / "original").read_text(), "live")
        self.assertEqual((self.desktop.etc / "nixos/configuration.nix").read_text(), "live system")

    def test_restore_preserves_replaced_files_and_backup(self):
        backup = self.backup()
        self.change_live_files()
        result = self.desktop.run(RESTORE)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.desktop.home / ".config/original").read_text(), ".config")
        recovery = next(self.desktop.home.glob(".dots-restore.*"))
        self.assertEqual((recovery / ".config/original").read_text(), "live")
        self.assertEqual((recovery / "status").read_text(), "complete\n")
        self.assertEqual((backup / ".config/original").read_text(), ".config")

    def test_missing_backup_does_not_touch_live_files(self):
        self.change_live_files()
        result = self.desktop.run(RESTORE)
        self.assertNotEqual(result.returncode, 0)
        self.assert_live_files()
        self.assertFalse(any(command[0] in {"cp", "mv", "chown"} for command in self.desktop.commands()))

    def test_incomplete_backup_is_rejected(self):
        backup = self.backup()
        shutil.rmtree(backup / ".local")
        self.change_live_files()
        result = self.desktop.run(RESTORE)
        self.assertNotEqual(result.returncode, 0)
        self.assert_live_files()

    def test_corrupt_manifest_is_rejected(self):
        backup = self.backup()
        (backup / ".dots-manifest").write_text("moxi-backup-v1\nnixos\tpresent\n../outside\tpresent\n")
        self.change_live_files()
        result = self.desktop.run(RESTORE)
        self.assertNotEqual(result.returncode, 0)
        self.assert_live_files()

    def test_failed_staging_leaves_destinations_untouched(self):
        self.backup()
        self.change_live_files()
        result = self.desktop.run(RESTORE, FAIL_COMMAND="cp", FAULT_MATCH=".local/.")
        self.assertNotEqual(result.returncode, 0)
        self.assert_live_files()

    def test_failed_ownership_change_prevents_publication(self):
        self.backup()
        self.change_live_files()
        result = self.desktop.run(RESTORE, FAIL_COMMAND="chown", FAULT_MATCH=".icons")
        self.assertNotEqual(result.returncode, 0)
        self.assert_live_files()

    def test_failed_later_replacement_recovers_earlier_replacement(self):
        self.backup()
        self.change_live_files()
        result = self.desktop.run(RESTORE, FAIL_COMMAND="mv", FAULT_MATCH="/home/audituser/.local")
        self.assertNotEqual(result.returncode, 0)
        self.assert_live_files()

    def test_termination_after_rename_recovers_original_files(self):
        self.backup()
        self.change_live_files()
        result = self.desktop.run(RESTORE, SIGNAL_COMMAND="mv", FAULT_MATCH="/home/audituser/.config")
        self.assertEqual(result.returncode, 143, result.stderr)
        self.assert_live_files()

    def test_uncatchable_interruption_retains_files_and_blocks_retry(self):
        self.backup()
        self.change_live_files()
        result = self.desktop.run(RESTORE, SIGNAL_COMMAND="mv", FAULT_MATCH="/home/audituser/.config", TEST_SIGNAL="SIGKILL")
        self.assertNotEqual(result.returncode, 0)
        recovery = next(self.desktop.home.glob(".dots-restore.*"))
        self.assertEqual((recovery / ".config/original").read_text(), "live")
        retry = self.desktop.run(RESTORE)
        self.assertNotEqual(retry.returncode, 0)
        self.assertIn("unfinished operation", retry.stderr)

    def test_originally_absent_directory_is_removed_without_deletion(self):
        shutil.rmtree(self.desktop.home / ".icons")
        self.backup()
        (self.desktop.home / ".icons").mkdir()
        (self.desktop.home / ".icons/new").write_text("new")
        result = self.desktop.run(RESTORE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.desktop.home / ".icons").exists())
        recovery = next(self.desktop.home.glob(".dots-restore.*"))
        self.assertEqual((recovery / ".icons/new").read_text(), "new")

    def test_complete_legacy_backup_is_supported(self):
        backup = self.backup()
        (backup / ".dots-manifest").unlink()
        self.change_live_files()
        result = self.desktop.run(RESTORE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.desktop.home / ".local/original").read_text(), ".local")

    def test_existing_system_backup_keeps_its_precedence(self):
        self.backup()
        shutil.copytree(self.desktop.etc / "nixos", self.desktop.etc / "nixos.bak")
        (self.desktop.etc / "nixos.bak/configuration.nix").write_text("legacy system")
        result = self.desktop.run(RESTORE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.desktop.etc / "nixos/configuration.nix").read_text(), "legacy system")
        self.assertTrue((self.desktop.etc / "nixos.bak").exists())

    def test_staged_ownership_does_not_follow_external_symlinks(self):
        external = self.desktop.work / "personal-file"
        external.write_text("personal")
        (self.desktop.home / ".config/reference").symlink_to("/work/personal-file")
        self.backup()
        before = external.stat().st_ctime_ns
        result = self.desktop.run(RESTORE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(external.stat().st_ctime_ns, before)
        self.assertTrue((self.desktop.home / ".config/reference").is_symlink())


class ApplyTests(InstallerTestCase):
    def test_hardware_generation_fallback_is_still_available(self):
        (self.desktop.etc / "nixos/hardware-configuration.nix").unlink()
        self.backup()
        result = self.desktop.run(APPLY)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(any(command[0] == "nixos-generate-config" for command in self.desktop.commands()))

    def test_requires_valid_backup_before_replacing_anything(self):
        result = self.desktop.run(APPLY)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.desktop.home / ".config/original").read_text(), ".config")
        self.assertFalse(any(command[0] == "nixos-rebuild" for command in self.desktop.commands()))

    def test_success_stows_packages_and_limits_ownership_to_managed_paths(self):
        self.backup()
        original_ctime = (self.desktop.home / ".local/original").stat().st_ctime_ns
        result = self.desktop.run(APPLY)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.desktop.home / ".config/example").is_symlink())
        self.assertTrue((self.desktop.etc / "nixos").is_symlink())
        self.assertEqual((self.desktop.home / ".local/original").read_text(), ".local")
        self.assertEqual((self.desktop.home / ".local/original").stat().st_ctime_ns, original_ctime)
        self.assertTrue((self.desktop.etc / "nixos.bak/hardware-configuration.nix").exists())
        commands = self.desktop.commands()
        self.assertTrue(any(command[0] == "nixos-rebuild" for command in commands))
        self.assertTrue(any(command[:3] == ["run-as", "audituser", "stow"] for command in commands))
        for command in commands:
            if command[0] == "chown":
                self.assertNotIn("-R", command)
                self.assertNotIn("/home/audituser", command)
                self.assertNotIn("/home/audituser/.local/original", command)
                self.assertIn("-h", command)

    def test_failed_stow_preflight_restores_displaced_directories(self):
        self.backup()
        result = self.desktop.run(APPLY, FAIL_COMMAND="stow", FAULT_MATCH="--simulate")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.desktop.home / ".config/original").read_text(), ".config")
        self.assertEqual((self.desktop.home / ".icons/original").read_text(), ".icons")
        self.assertFalse((self.desktop.etc / "nixos").is_symlink())

    def test_stow_conflict_preserves_unmanaged_local_file(self):
        self.backup()
        (self.desktop.home / ".local/bin").mkdir()
        (self.desktop.home / ".local/bin/example").write_text("personal file")
        result = self.desktop.run(APPLY)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.desktop.home / ".local/bin/example").read_text(), "personal file")
        self.assertEqual((self.desktop.home / ".config/original").read_text(), ".config")

    def test_existing_activation_fallback_is_preserved(self):
        self.backup()
        result = self.desktop.run(APPLY, REBUILD_STATUS="1")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(any(command[0] == "switch-to-configuration" for command in self.desktop.commands()))

    def test_activation_failure_does_not_pretend_to_reverse_system_activation(self):
        self.backup()
        result = self.desktop.run(APPLY, REBUILD_STATUS="1", DIRECT_ACTIVATION_STATUS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.desktop.etc / "nixos").is_symlink())
        recovery = next(self.desktop.home.glob(".dots-apply.*"))
        self.assertTrue((recovery / ".config/original").is_file())

    def test_new_user_retains_existing_creation_flow(self):
        result = self.desktop.run(BACKUP, DOTS_USER="newuser")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.desktop.home.parent / "newuser").stat().st_mode & 0o777, 0o755)
        result = self.desktop.run(APPLY, DOTS_USER="newuser", CREATE_USER="newuser")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(any(command[:4] == ["chown", "-h", "--", "newuser"] and command[4] == "/home/newuser" for command in self.desktop.commands()))

    def test_materialized_kde_configuration_is_owned_after_conversion(self):
        source = self.desktop.repo / "Configs/config/.config/kscreenlockerrc"
        source.write_text("wallpaper=/home/moxiu/walls/example\n")
        sed = self.desktop.work / "bin/sed"
        sed.write_text(f"#!{sys.executable}\n" + '''
import json
import os
import sys

with open("/work/commands.jsonl", "a") as log:
    log.write(json.dumps(["sed", *sys.argv[1:]]) + "\\n")
os.execv(REAL_SED, [REAL_SED, *sys.argv[1:]])
'''.replace("REAL_SED", repr(shutil.which("sed"))))
        sed.chmod(0o755)
        self.backup()
        result = self.desktop.run(APPLY)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        target = self.desktop.home / ".config/kscreenlockerrc"
        self.assertFalse(target.is_symlink())
        self.assertEqual(target.read_text(), "wallpaper=/home/audituser/walls/example\n")
        commands = self.desktop.commands()
        conversion = next(index for index, command in enumerate(commands) if command[:2] == ["sed", "s|/home/moxiu|/home/audituser|g"])
        ownership = commands.index(["chown", "-h", "--", "audituser", "/home/audituser/.config/kscreenlockerrc"])
        self.assertGreater(ownership, conversion)


class RecoveryCommandTests(InstallerTestCase):
    def setUp(self):
        super().setUp()
        curl = self.desktop.work / "bin/curl"
        curl.write_text(f"#!{sys.executable}\n" + '''
import json
import os
import sys

with open("/work/commands.jsonl", "a") as log:
    log.write(json.dumps(["curl", *sys.argv[1:]]) + "\\n")
sys.exit(int(os.environ.get("TELEMETRY_STATUS", "0")))
''')
        curl.chmod(0o755)

    def telemetry_calls(self):
        return [command for command in self.desktop.commands() if command[0] == "curl"]

    def test_normal_install_entrypoint_still_completes(self):
        result = self.desktop.run(MAIN, "--user", "audituser")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("DONE!", result.stdout)
        self.assertEqual(self.telemetry_calls(), [[
            "curl", "--disable", "--silent", "--fail", "--max-time", "3", "--request", "POST",
            "--user-agent", "", "--output", "/dev/null", "https://stats.vacpro.fyi/install",
        ]])
        commands = self.desktop.commands()
        activation = next(index for index, command in enumerate(commands) if command[0] == "nixos-rebuild")
        self.assertGreater(commands.index(self.telemetry_calls()[0]), activation)

    def test_telemetry_failure_does_not_fail_installation(self):
        result = self.desktop.run(MAIN, "--user", "audituser", TELEMETRY_STATUS="28")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("DONE!", result.stdout)
        self.assertEqual(len(self.telemetry_calls()), 1)

    def test_failed_backup_does_not_send_telemetry(self):
        result = self.desktop.run(MAIN, "--user", "audituser", FAIL_COMMAND="cp", FAULT_MATCH=".config/.")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.telemetry_calls(), [])

    def test_failed_install_activation_does_not_send_telemetry(self):
        result = self.desktop.run(MAIN, "--user", "audituser", REBUILD_STATUS="1", DIRECT_ACTIVATION_STATUS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.telemetry_calls(), [])

    def test_help_does_not_send_telemetry(self):
        result = self.desktop.run(MAIN, "--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.telemetry_calls(), [])

    def test_invalid_backup_prevents_activation(self):
        result = self.desktop.run(MAIN, "--rollback_restore", "--user", "audituser")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(command[0] == "nixos-rebuild" for command in self.desktop.commands()))

    def test_restores_before_activation(self):
        self.backup()
        (self.desktop.etc / "nixos/configuration.nix").write_text("live system")
        result = self.desktop.run(MAIN, "-rr", "-u", "audituser")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.desktop.work / "activated-config").read_text(), "{ original = true; }\n")
        self.assertIn(["nixos-rebuild", "switch"], self.desktop.commands())
        self.assertEqual(self.telemetry_calls(), [])

    def test_flake_restore_uses_the_selected_user_configuration(self):
        (self.desktop.etc / "nixos/flake.nix").write_text("{}\n")
        self.backup()
        result = self.desktop.run(MAIN, "-rr", "-u", "audituser", DOTS_USER="root")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(["nixos-rebuild", "switch", "--flake", "/etc/nixos#audituser"], self.desktop.commands())

    def test_activation_failure_is_reported(self):
        self.backup()
        result = self.desktop.run(MAIN, "-rr", "-u", "audituser", REBUILD_STATUS="19")
        self.assertEqual(result.returncode, 19, result.stdout + result.stderr)
        self.assertNotIn("both script's finished", result.stdout)

    def test_user_argument_requires_a_value(self):
        result = self.desktop.run(MAIN, "--user")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires a username", result.stderr)
