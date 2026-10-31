{ config, lib, pkgs, ... }:

let
  cfg = config.boot.loader.grub.signedSnapshot;
  bootTargets = config.boot.loader.grub.mirroredBoots;
  grubEfi = pkgs.grub2.override { efiSupport = true; };
  snapshot = pkgs.writeShellApplication {
    name = "grub-secure-snapshot";
    runtimeInputs = [ pkgs.python3 grubEfi pkgs.sbsigntool ];
    text = ''
      exec python3 ${../scripts/grub-secure-snapshot.py} \
        --boot ${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint} \
        --pki ${lib.escapeShellArg cfg.pkiBundle} "$@"
    '';
  };
  setup = pkgs.writeShellApplication {
    name = "grub-secure-setup";
    runtimeInputs = [ pkgs.python3 pkgs.sbctl pkgs.efibootmgr pkgs.util-linux snapshot ];
    text = ''
      exec python3 ${../scripts/grub-secure-setup.py} \
        --boot ${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint} \
        --pki ${lib.escapeShellArg cfg.pkiBundle} "$@"
    '';
  };
in
{
  options.boot.loader.grub.signedSnapshot = {
    enable = lib.mkEnableOption "a separate signed, self-contained GRUB EFI image";
    pkiBundle = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sbctl";
      description = "Directory containing sbctl keys; never put private keys in the Nix store.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.boot.loader.grub.enable && config.boot.loader.grub.efiSupport;
        message = "GRUB signed snapshots require EFI GRUB.";
      }
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux"
          && lib.versionAtLeast grubEfi.version "2.14";
        message = "This GRUB signed snapshot requires x86_64 and GRUB >= 2.14 (--disable-cli).";
      }
      {
        assertion = config.boot.loader.grub.copyKernels
          && builtins.length bootTargets == 1
          && (builtins.head bootTargets).path == config.boot.loader.efi.efiSysMountPoint;
        message = "GRUB signed snapshots require one GRUB boot directory on the EFI partition and copyKernels enabled (normally the ESP mounted at /boot).";
      }
    ];

    environment.systemPackages = [ snapshot setup pkgs.sbctl pkgs.sbsigntool pkgs.efibootmgr ];
    boot.loader.grub.copyKernels = lib.mkDefault true;
    boot.loader.grub.useOSProber = lib.mkDefault false;

    # Run after the normal installer and Minegrub's grubenv initialization.
    # A fresh installation can still boot normally before keys are created.
    boot.loader.grub.extraInstallCommands = lib.mkAfter ''
      if [ -f ${lib.escapeShellArg (cfg.pkiBundle + "/keys/db/db.key")} ]; then
        ${snapshot}/bin/grub-secure-snapshot
      else
        echo "GRUB Secure Boot: no sbctl db key yet; signed snapshot not generated." >&2
      fi
    '';
  };
}
