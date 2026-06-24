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
      timeout = 30;
      configurationLimit = 3;
    };
  };

  # decrypt partitions
  boot.initrd.luks.devices = {
    root = {
      device = "/dev/disk/by-uuid/7e1fe4e2-173f-4f5c-97e5-b0a961d1c18d";
      preLVM = true;
    };
  };
}
