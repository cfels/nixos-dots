# Secure Boot with GRUB and Minegrub

The module keeps the ordinary GRUB installation and builds a separate signed
image at `EFI/NixOS-secure/grubx64.efi` after each bootloader installation.
NixOS rebuilds refresh it automatically using the same signing keys.

## Supported systems

x86_64 NixOS, GRUB >= 2.14, and a mounted GPT/FAT EFI system partition. NixOS
GRUB's boot directory must be that EFI partition (normally mounted at `/boot`),
with `copyKernels` enabled. Separate `/boot` and `/boot/efi` layouts and mirrored
boot installations are not supported. Kernel/initrd entries must use the ESP's
`/kernels` directory. Minegrub's second
menu is included when present; ordinary NixOS GRUB also works. Setup detects
the disk, partition number, and partition UUID automatically.

External chainloaders, ARM, legacy BIOS, and arbitrary custom GRUB layouts are
not supported. Disable `boot.loader.grub.useOSProber` when using this module.

## Prepare and test

For a new dots installation, opt in:

```sh
bash ./installer --secure-boot
```

For an existing installation, rebuild your NixOS configuration once to install
the helper, then run:

```sh
sudo grub-secure-setup
```

The helper creates keys under `/var/lib/sbctl` only if none exist, signs the
image, detects the ESP, and reuses or creates its firmware entry. Partial key
bundles are rejected instead of overwritten. Existing matching entries are
reused. New entries use `--create-only`, preserving the working boot order.

Follow the exact one-time boot commands printed by the helper with Secure Boot
still disabled. Test the menus and boot NixOS, then check `sudo efibootmgr`:
BootCurrent should match the printed entry number. The helper never enrolls
keys, enables Secure Boot, changes boot order, or reboots automatically.

Do not add private keys to Git or Nix expressions. Back up `/var/lib/sbctl`
securely. Custom `pkiBundle` directories must be provisioned separately; the
helper generates file-based keys only at the default sbctl path.

## Enroll after the test boot succeeds

If your own keys are already enrolled, keep them and enable Secure Boot after
testing. Do not clear and re-enroll keys for updates.

For first-time enrollment, enter firmware settings and select Custom/Setup
Mode by removing only the Platform Key (PK). Preserve the other databases,
especially the forbidden-signature database (dbx). Firmware labels vary; do not
use a blanket erase or restore factory keys over your own enrolled keys.

Boot NixOS again and run:

```sh
sudo sbctl status
```

Setup Mode must report enabled before enrolling:

```sh
sudo sbctl enroll-keys --microsoft --firmware-builtin
```

These additional certificates can be needed for hardware Option ROMs and
vendor firmware updates, even without Windows. They also broaden which signed
software the firmware trusts. Built-in firmware certificates can themselves
include Microsoft certificates.

Enable Secure Boot in firmware, put **NixOS Secure GRUB** first in the boot
order, and reboot. Verify:

```sh
sudo sbctl status
sudo efibootmgr
```

Expected: Secure Boot enabled, Setup Mode disabled, and BootCurrent matching
the signed entry. If recovery through the original unsigned GRUB is necessary,
disable Secure Boot in firmware first.

## Updates and verification

Each rebuild signs every embedded kernel and the resulting GRUB image. Keys
must remain available under `/var/lib/sbctl`. A fresh install without keys skips
snapshot generation on its initial rebuild; the setup helper generates it
after creating keys. Other signing failures fail the rebuild hook.

Verify the outer image at any time (adjust paths for custom ESP/key locations):

```sh
sudo sbverify --cert /var/lib/sbctl/keys/db/db.pem /boot/EFI/NixOS-secure/grubx64.efi
```

`sbctl verify` may report unsigned files from the original bootloader. Those
are not dependencies of the signed snapshot, which boots embedded copies.

Minegrub's runtime theme updater changes the ordinary on-disk theme. Include a
later theme update in the signed image with:

```sh
sudo grub-secure-snapshot
```

The signed image uses a fixed main menu and does not import mutable `grubenv`.
Saved-entry and `grub-reboot` changes do not affect it. Menu editing, command
line access, and the rescue shell are disabled in the signed image. Select
retained generations using its normal menus. The image can be large because
it embeds all boot files referenced by retained generations, deduplicated by
filename.

## How it works

Both menus, themes, GRUB modules, kernels, and initrds are embedded into a
memdisk authenticated by the outer EFI signature. The menu points to that
memdisk instead of external boot files. Each kernel is also separately signed:
GRUB 2.14 hands it to firmware `LoadImage`, which requires the kernel's own PE
signature when Secure Boot is enabled. Initrds are covered by the outer image
signature. GRUB's `--disable-cli` prevents editing the signed configuration or
using an interactive shell to load unauthenticated files.

This does not authenticate the root filesystem or enforce Linux kernel-module
signatures. Older signed snapshots remain valid until their key or image is
revoked. This is a custom NixOS module, not upstream NixOS GRUB Secure Boot
support.

## Reuse elsewhere

Copy `modules/grub-secure-snapshot.nix` and the two `scripts/grub-secure-*.py`
files, preserving their relative paths. Import the module and enable
`boot.loader.grub.signedSnapshot.enable` alongside EFI GRUB. The module uses
`boot.loader.efi.efiSysMountPoint` and supplies all its tools. No Lanzaboote
input or GPG key is required. See the supported layouts above.

References: [GRUB security](https://www.gnu.org/software/grub/manual/grub/grub.html#Security),
[sbctl](https://github.com/Foxboron/sbctl), and
[firmware enrollment](https://nix-community.github.io/lanzaboote/getting-started/enable-secure-boot.html)
(the firmware steps also apply to GRUB; this module does not use Lanzaboote).
