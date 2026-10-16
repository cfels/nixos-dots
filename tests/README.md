# Regression checks and installer recovery

Run from the repository root:

```sh
python3 -B -m unittest discover -s tests -v
```

The tests require Python, Bash, Bubblewrap, GNU Stow, and the existing GNU command-line tools. Atomic directory replacement requires GNU `mv` with `--exchange` and `--no-copy`. Node.js checks the extracted panel JavaScript; Neovim/LuaJIT checks Lua module loading. Those two checks explicitly skip if their runtimes are unavailable. The suite does not install tools.

## Isolation

Installer and fetcher tests construct a disposable root filesystem. Only the Nix store and executable directories are mounted read-only from the host. `/etc`, `/home`, `/root`, `/run`, and the test repository are private to the test. Networking is disabled. Failure to start isolation is a test error, never a reason to run without it.

Nix activation, Git configuration, and font-cache updates are mocked. Existing-user Stow commands record the requested account, then run in the test's single-UID namespace. Ownership commands execute against the mapped namespace UID; tests verify that unmanaged files and symlink targets retain their metadata. Actual account allocation and cross-user permissions still require a disposable NixOS VM.

The lyrics responses in `fixtures/lyrics/providers.json` are synthetic fixtures based on the checked-in adapters, not captures from live services. They cover all 12 default search routes and five credential-gated routes. Tests use dummy credentials and a local `curl` substitute. No provider API is contacted.

Panel tests execute the existing JavaScript function bodies to check cancellation requests, track-key guards, and duration-only messages. They do not instantiate Quickshell, verify signal delivery order, or render animations. Process-group cancellation tests verify group cleanup, not Quickshell's process-tree termination semantics.

## Installer contracts

- `--user` / `-u`, `--help` / `-h`, and `--rollback_restore` / `-rr` remain available.
- Recovery validates the selected account and backup, restores files, then activates the restored configuration. It uses the selected user's flake configuration when a flake exists, or a regular rebuild for a non-flake backup. It does not select an earlier NixOS generation.
- Backup preserves the original saved NixOS directory while refreshing the home-directory snapshot. Copies are verified before publication. The prior complete snapshot is retained.
- `.dots-manifest` records `present` or `absent` for `nixos`, `.config`, `.local`, and `.icons`, following the `moxi-backup-v1` header. An absent directory is restored to absence without deleting the displaced directory.
- Complete legacy backups without a manifest remain supported. Missing or linked top-level backup directories are rejected. A directory source symlink is materialized during new backup creation; nested symlinks are preserved.
- A valid, non-symlink `/etc/nixos.bak` retains its existing restore precedence and is preserved.
- Restore stages and verifies every source before replacing a destination. File replacements retain their previous contents and use same-filesystem atomic renames. Catchable failures attempt to reverse completed file replacements.
- Apply checks its backup, preserves displaced `.config` and `.icons`, and simulates Stow before applying links. Existing-user Stow runs as that user. Ownership changes cover managed paths without following links or recursively changing the entire home.
- The existing apply-time direct-activation fallback is unchanged. File publication is committed before system activation begins. Activation failure is reported; it does not trigger an unverified attempt to undo system activation.

## Retained data and interruption recovery

Backup snapshots use `$USER_HOME/dots-backup` and retained `.dots-backup.*` directories. File transactions retain `.dots-restore.*` or `.dots-apply.*` directories in the selected home and corresponding directories under `/etc`. Nothing automatically prunes these directories, so repeated operations consume additional space.

Each file transaction records a `status`, a `journal`, and the system staging path in `system-stage`. Journal rows record the operation, destination, staging path, and original/replacement device-and-inode identities. An exchanged staging path contains the displaced object after publication.

`complete` means file publication completed; `recovered` means failed file publication was reversed. These do not prove that NixOS activation succeeded. An unfinished or `manual-recovery-required` transaction blocks a new installer operation. Inspect its journal and retained objects before retrying. Do not mark it complete merely to bypass the guard.

A forced kill can leave a mixture of old and new directories, but displaced files remain at the recorded paths. Power-loss durability, full-disk behavior, and manual recovery should be exercised in a disposable VM. This suite does not establish crash consistency across a machine power failure.

Stow's changes to `.local` and `walls` are not a multi-directory transaction. Preflight rejects conflicts, and existing unmanaged files are preserved. A failure after Stow begins may leave newly created managed links there; the backup remains available for restoration.

## Remaining manual checks

Use a disposable NixOS VM before trusting installation or recovery on a daily-driver machine. Cover an existing user, a new user, a custom home, privilege escalation, full disk, interrupted copy, interruption between replacements, activation failure, and subsequent recovery. The hardware/LUKS generation logic is unchanged and only its command boundaries are mocked.

After the Lua cleanup, check login startup once: wallpaper restoration, clipboard watchers, Quickshell startup, displays, and keybindings. Module execution order is covered automatically; a compositor session is not.

For the unchanged desktop, the remaining integration baseline is overlay switching and focus, media playback and seeking, lyrics loading and synchronization, clipboard image transitions, notifications, screenshots, wallpaper renderer handoff, lock/unlock restoration, and theme refresh. Live provider compatibility, frame pacing, and QML object lifetimes require the running desktop.
