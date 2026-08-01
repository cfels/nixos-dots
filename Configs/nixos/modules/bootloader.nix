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
      device = "/dev/disk/by-uuid/3c2a65f7-5935-4795-a7fa-774c540ed4c2";
      preLVM = true;
    };
  };
}
