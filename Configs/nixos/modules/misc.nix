{ config, inputs, pkgs, lib, ... }:
{
  # kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  
  # init
  boot.initrd.systemd.enable = true;

  # hostname
  networking.hostName = "moxiu";
  
  # ssh
  services.openssh.enable = true;
  programs.ssh.startAgent = true;

  # fix agent
  services.gnome.gcr-ssh-agent.enable = false;

  # stuff
  programs.fish.enable = true;
  
  # stuff 2
  environment.systemPackages = with pkgs; [
    inputs.kwin-better-blur-dx.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # kde portal enable
  xdg.portal = {
   enable = true;
   extraPortals = [
     pkgs.kdePackages.xdg-desktop-portal-kde
     pkgs.xdg-desktop-portal-hyprland
     pkgs.xdg-desktop-portal-gtk
   ];
   config = {
     common.default = [ "gtk" "kde" ];
     hyprland = {
       default = [ "hyprland" "gtk" ];
       "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
       "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
       "org.freedesktop.impl.portal.GlobalShortcuts" = [ "hyprland" ];
     };
   };
  };

  systemd.user.targets.hyprland-session = {
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
  };

  environment.pathsToLink = [ "/lib/pkgconfig" "/share/pkgconfig" ];
  
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="f54d", MODE="0666"
  '';

  environment.sessionVariables = {
    PKG_CONFIG_PATH = "/run/current-system/sw/lib/pkgconfig:/run/current-system/sw/share/pkgconfig";
  };

  # steam millenium
  #nixpkgs.overlays = [ inputs.millennium.overlays.default ];
  
  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "Bibata-Modern-Ice";
    HYPRCURSOR_SIZE = "24";
  };
  
  # virtualbox
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "moxiu" ];

  # stim
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraPkgs = pkgs: [ pkgs.bibata-cursors ];
    };
    extraCompatPackages = [
      inputs.proton-ge.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.proton-cachyos.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
