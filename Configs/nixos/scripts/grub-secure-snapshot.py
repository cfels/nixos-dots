"""Embed NixOS GRUB boot files in one signed EFI application.

Only the snapshot is transformed. The ordinary GRUB installation is untouched.
The firmware authenticates the entire memdisk, including kernels and initrds.
GRUB's CLI/editor/rescue shell are disabled using GRUB 2.14's --disable-cli.
"""

import argparse
import fcntl
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def copy_asset(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        shutil.copytree(source, destination, symlinks=False)
    else:
        shutil.copyfile(source, destination)


def allow_menu_boots(config):
    # --disable-cli denies authenticated entries, so every fixed signed menu
    # entry/submenu must explicitly permit ordinary booting without a password.
    def unrestricted(match):
        line = match[0]
        if "--unrestricted" not in line:
            line = line.rstrip()[:-1].rstrip() + " --unrestricted {"
        return line

    return re.sub(r"(?m)^\s*(?:menuentry|submenu)\s+[^\n]*\{[ \t]*$",
                  unrestricted, config)


def prepare_snapshot(boot, stage):
    config = (boot / "grub/grub.cfg").read_text()
    mainmenu_path = boot / "grub/mainmenu.cfg"
    mainmenu = mainmenu_path.read_text() if mainmenu_path.is_file() else ""

    # Deliberately support this host's NixOS linux/initrd entries only. EFI
    # chainloading and other operating systems need a separate trust policy.
    if re.search(r"^\s*(?:chainloader|multiboot2?|linuxefi|linux16|initrdefi|source)\b",
                 config + "\n" + mainmenu, re.MULTILINE):
        raise ValueError("Unsupported external boot command; refusing to sign this menu")
    for menu in [config, mainmenu]:
        for command in re.findall(r"(?m)^\s*configfile\s+([^\n]+)", menu):
            if command.strip() not in ["$prefix/grub.cfg", "$prefix/$config_file"]:
                raise ValueError("Only the embedded Minegrub configuration files are supported")
        if re.search(r"(?m)^\s*set\s+(?:root|prefix|drive1|config_file)=", menu):
            raise ValueError("Unexpected boot path override in generated menu")
        if any(device != "$drive1" for device in re.findall(r"\(([^)]+)\)/", menu)):
            raise ValueError("Unexpected external device reference in generated menu")

    searches = re.findall(r"^\s*search --set=drive1 --fs-uuid ([\w-]+)\s*$",
                          config, re.MULTILINE)
    if not searches or len(set(searches)) != 1:
        raise ValueError("Expected NixOS entries on a single EFI filesystem")

    # Map EVERY generation to the authenticated memdisk rather than /boot.
    config = re.sub(r"^\s*search --set=drive1 --fs-uuid [\w-]+\s*$",
                    "    set drive1=memdisk", config, flags=re.MULTILINE)

    # Do not import mutable on-disk grubenv, or try to update a read-only memdisk.
    # The main menu selection is fixed in the signed configuration instead.
    config, env_blocks = re.subn(
        r"(?m)^\s*if \[ -s \$prefix/grubenv \]; then\s*\n"
        r"\s*load_env\s*\n\s*fi\s*$",
        "    set config_file=mainmenu.cfg" if mainmenu else "    true", config)
    if env_blocks != 1:
        raise ValueError("Unexpected grubenv loader; refusing to sign this menu")
    config = re.sub(r"(?m)^\s*save_env[^\n]*$", "      true", config)
    if re.search(r"(?m)^\s*(?:load_env|search)\b", config + "\n" + mainmenu):
        raise ValueError("Unexpected external filesystem/environment access in generated menu")
    # Upstream double-minegrub-menu includes this shell-script header in extraConfig.
    config = re.sub(r"(?m)^\s*exec tail -n \+3 \$0\s*$", "", config)

    boot_files = set()
    kernels = set()
    for line in config.splitlines():
        if not re.match(r"\s*(?:linux|initrd)\s", line):
            continue
        command, *arguments = line.split()
        paths = arguments[:1] if command == "linux" else arguments
        for argument in paths:
            match = re.fullmatch(r"\(\$drive1\)/+kernels/([\w.+-]+)", argument)
            if not match:
                raise ValueError(f"Kernel/initrd is not on the embedded filesystem: {argument}")
            boot_files.add(match[1])
            if command == "linux":
                kernels.add(match[1])
    if not kernels:
        raise ValueError("No NixOS kernel/initrd entries found")
    for name in sorted(boot_files):
        copy_asset(boot / "kernels" / name, stage / "kernels" / name)

    # Include generated theme/font/image assets when present.
    for name in ["theme", "converted-font.pf2", "background.png"]:
        if (boot / name).exists():
            copy_asset(boot / name, stage / name)
    if (boot / "grub/themes").is_dir():
        copy_asset(boot / "grub/themes", stage / "boot/grub/themes")
    (stage / "boot/grub").mkdir(parents=True, exist_ok=True)
    (stage / "boot/grub/grub.cfg").write_text(
        "# Signed snapshot: all boot assets below are embedded in this EFI image.\n"
        "set root=memdisk\n" + allow_menu_boots(config))
    if mainmenu:
        (stage / "boot/grub/mainmenu.cfg").write_text(allow_menu_boots(mainmenu))
    return [stage / "kernels" / name for name in sorted(kernels)]


def sign_image(source, destination, key, cert):
    subprocess.run(["sbsign", "--key", str(key), "--cert", str(cert),
                    "--output", str(destination), str(source)], check=True)
    subprocess.run(["sbverify", "--cert", str(cert), str(destination)], check=True)


def sign_kernels(kernels, key, cert):
    # GRUB 2.14's EFI Linux loader calls firmware LoadImage on the kernel.
    # The outer GRUB signature authenticates the memdisk, but firmware still
    # requires a separate PE signature on each kernel it executes.
    for kernel in kernels:
        signed = kernel.with_name(kernel.name + ".signed")
        sign_image(kernel, signed, key, cert)
        os.replace(signed, kernel)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--boot", type=Path, default=Path("/boot"))
    parser.add_argument("--pki", type=Path, default=Path("/var/lib/sbctl"))
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error("Run as root (sudo grub-secure-snapshot)")
    if not os.path.ismount(args.boot):
        parser.error(f"EFI filesystem is not mounted at {args.boot}")
    key = args.pki / "keys/db/db.key"
    cert = args.pki / "keys/db/db.pem"
    if not key.is_file() or not cert.is_file():
        parser.error("sbctl signing key/certificate missing; run sudo sbctl create-keys first")

    with open("/run/lock/grub-secure-snapshot.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with tempfile.TemporaryDirectory(prefix="grub-secure-", dir="/var/tmp") as work:
            work = Path(work)
            stage = work / "stage"
            kernels = prepare_snapshot(args.boot, stage)
            sign_kernels(kernels, key, cert)
            unsigned = work / "grubx64.unsigned.efi"
            signed = work / "grubx64.efi"
            # mkstandalone supplies its own modules inside the same signed memdisk.
            # Direct firmware trust uses our db key; no shim is involved.
            subprocess.run([
                "grub-mkstandalone", "-O", "x86_64-efi",
                "--disable-shim-lock", "--disable-cli",
                "--locales=", "--fonts=", "--themes=", "--compress=no",
                "--output", str(unsigned),
                *[f"{path.relative_to(stage)}={path}" for path in sorted(stage.iterdir())],
            ], check=True)
            sign_image(unsigned, signed, key, cert)

            destination = args.boot / "EFI/NixOS-secure/grubx64.efi"
            destination.parent.mkdir(parents=True, exist_ok=True)
            if shutil.disk_usage(destination.parent).free < signed.stat().st_size + 1048576:
                raise OSError("Not enough free space on the EFI filesystem for a new snapshot")
            # Replace only after a complete signed image passes verification.
            fd, temporary = tempfile.mkstemp(prefix=".grubx64-", suffix=".efi",
                                             dir=destination.parent)
            try:
                with os.fdopen(fd, "wb") as output, signed.open("rb") as source:
                    shutil.copyfileobj(source, output)
                    output.flush()
                    os.fsync(output.fileno())
                os.replace(temporary, destination)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
            print(f"Signed GRUB snapshot installed: {destination} ({len(kernels)} signed kernels)")
            print("Firmware entries and Secure Boot settings were not changed.")


if __name__ == "__main__":
    main()
