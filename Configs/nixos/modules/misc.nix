{ config, inputs, pkgs, lib, ... }:
{
  # kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  
  # init
  boot.initrd.systemd.enable = true;

  # hostname
  networking.hostName = "moxiu";
  
  # gpg
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    settings = {
      default-cache-ttl = 34560000;
      max-cache-ttl = 34560000;
    };
  };

  services.openssh.enable = true;
  
  # stuff
  programs.fish.enable = true;
  
  # stuff 2
  environment.systemPackages = with pkgs; [
    inputs.kwin-better-blur-dx.packages.${pkgs.system}.default
    inputs.vm_curator.packages.${pkgs.system}.default
    OVMF
  ];

  # get write access for my mouse
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="f54d", MODE="0666"
  '';
  
  # kde portal enable
  xdg.portal = {
   enable = true;
   extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };
  xdg.portal.config.common.default = [ "kde" ];

  environment.pathsToLink = [ "/lib/pkgconfig" "/share/pkgconfig" ];
  
  environment.sessionVariables = {
    PKG_CONFIG_PATH = "/run/current-system/sw/lib/pkgconfig:/run/current-system/sw/share/pkgconfig";
  };
}
