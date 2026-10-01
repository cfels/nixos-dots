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
  boot.initrd.luks.devices = {
    root = {
      device = "/dev/disk/by-uuid/7c844975-2cb8-4148-9239-6d84b04b4ad4";
      preLVM = true;
    };
  };
}
