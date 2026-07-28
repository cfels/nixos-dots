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
      device = "/dev/disk/by-uuid/ed826d0b-e1cf-4c90-821e-62a0d82aa167";
      preLVM = true;
    };
  };
}
