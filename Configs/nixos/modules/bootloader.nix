{ config, pkgs, lib, ... }:

{
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
    };
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      useOSProber = true;
      configurationLimit = 3;
    };
    timeout = 30;
  };

  # decrypt partitions
  boot.initrd.luks.devices = import ../luks.nix;
}
