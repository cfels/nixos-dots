"""Prepare GRUB Secure Boot without enrolling keys or changing boot order."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import uuid


LOADER = r"\EFI\NixOS-secure\grubx64.efi"
LABEL = "NixOS Secure GRUB"


def read_json(command):
    return json.loads(subprocess.check_output(command, text=True))


def detect_esp(boot):
    if not os.path.ismount(boot):
        raise ValueError(f"EFI filesystem is not mounted at {boot}")
    mounts = read_json(["findmnt", "--json", "--mountpoint", str(boot),
                        "--output", "SOURCE,FSTYPE"])["filesystems"]
    if len(mounts) != 1 or mounts[0]["fstype"] != "vfat":
        raise ValueError("Expected one mounted FAT EFI system partition")
    source = str(Path(mounts[0]["source"]).resolve())
    rows = read_json(["lsblk", "--json", "--paths", "--nodeps", "--output",
                      "PATH,TYPE,PARTN,PKNAME,PARTUUID,PARTTYPE", source])["blockdevices"]
    if len(rows) != 1:
        raise ValueError("Could not identify the EFI partition")
    row = rows[0]
    if row["type"] != "part" or str(row.get("parttype", "")).lower() != \
            "c12a7328-f81f-11d2-ba4b-00a0c93ec93b":
        raise ValueError("Secure Boot setup requires a GPT EFI system partition")
    disk = row.get("pkname")
    part = int(row["partn"])
    partuuid = str(uuid.UUID(row["partuuid"]))
    if not disk or part < 1:
        raise ValueError("Could not identify the EFI disk and partition number")
    disk = disk if disk.startswith("/dev/") else "/dev/" + disk
    return disk, part, partuuid


def find_entry(entries, partition, partuuid):
    device = f"HD({partition},GPT,{partuuid},".lower()
    for line in entries.splitlines():
        match = re.match(r"Boot([0-9a-fA-F]{4})\*?\s", line)
        if match and device in line.lower() and LOADER.lower() in line.lower():
            return match[1].upper()
    return None


def ensure_keys(pki, *, allow_create=True):
    required = [pki / "keys" / name / (name + suffix)
                for name in ["PK", "KEK", "db"] for suffix in [".key", ".pem"]]
    required.append(pki / "GUID")
    if all(path.is_file() for path in required):
        return
    if any(path.exists() for path in required) or (pki / "GUID").exists():
        raise ValueError(f"Incomplete key bundle at {pki}; existing keys will not be overwritten")
    if not allow_create:
        raise ValueError("Signing keys are missing while Secure Boot is enabled; restore the original key bundle first")
    if pki != Path("/var/lib/sbctl"):
        raise ValueError(f"Provision your custom sbctl key bundle at {pki} before setup")
    subprocess.run(["sbctl", "create-keys"], check=True)
    if not all(path.is_file() for path in required):
        raise ValueError("sbctl did not produce the expected file-based key bundle")


def prepare(boot, pki):
    # Validate firmware and storage before creating any keys or EFI files.
    status = read_json(["sbctl", "status", "--json"])
    disk, partition, partuuid = detect_esp(boot)
    ensure_keys(pki, allow_create=not status["secure_boot"])
    subprocess.run(["grub-secure-snapshot", "--boot", str(boot), "--pki", str(pki)], check=True)
    entries = subprocess.check_output(["efibootmgr", "--verbose"], text=True)
    entry = find_entry(entries, partition, partuuid)
    if entry is None:
        # Preserve the working BootOrder. Testing is a separate one-time boot.
        subprocess.run(["efibootmgr", "--create-only", "--disk", disk,
                        "--part", str(partition), "--label", LABEL,
                        "--loader", LOADER], check=True)
        entries = subprocess.check_output(["efibootmgr", "--verbose"], text=True)
        entry = find_entry(entries, partition, partuuid)
        if entry is None:
            raise ValueError("Firmware entry was not found after creation")
    current = re.search(r"(?m)^BootCurrent:\s*([0-9A-Fa-f]{4})", entries)
    print(f"Signed GRUB is ready as Boot{entry} on {disk}, partition {partition}.")
    if status["secure_boot"] and current and current[1].upper() == entry:
        print("Secure Boot is enabled and this session booted through that entry.")
        return
    print("Test this entry with a one-time boot:")
    print(f"  sudo efibootmgr --bootnext {entry}")
    print("  sudo reboot")
    print(f"After booting, check that efibootmgr reports BootCurrent: {entry}.")
    if status["secure_boot"]:
        print("Secure Boot is already enabled; keep your enrolled keys.")
        print("After testing, put NixOS Secure GRUB first in the firmware boot order.")
        return
    if status["setup_mode"]:
        print("After a successful test boot, enroll your existing keys:")
    else:
        print("If your keys are not enrolled, enter firmware Setup Mode first:")
        print("  Remove only the Platform Key (PK); preserve dbx and the other databases.")
    print("  sudo sbctl enroll-keys --microsoft --firmware-builtin")
    print("Then enable Secure Boot in firmware and put NixOS Secure GRUB first.")
    print("No keys were enrolled, boot order changed, or reboot performed by this command.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--boot", type=Path, default=Path("/boot"))
    parser.add_argument("--pki", type=Path, default=Path("/var/lib/sbctl"))
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error("Run as root (sudo grub-secure-setup)")
    try:
        prepare(args.boot, args.pki)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"GRUB Secure Boot setup: {error}\n")


if __name__ == "__main__":
    main()
