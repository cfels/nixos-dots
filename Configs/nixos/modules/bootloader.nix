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
      device = "/dev/disk/by-uuid/6a858e6-dc07-4e03-99c4-eef0cb6df975";
      preLVM = true;
    };
  };
}
