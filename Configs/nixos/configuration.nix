{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.

      ./hardware-configuration.nix
      ./modules/default.nix
    ];

  system.stateVersion = "26.05";

  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="f54f", MODE="0666"
  '';
}
