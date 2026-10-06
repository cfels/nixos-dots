{ config, inputs, pkgs, lib, username, hostName, ... }:
{
  # kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  
  # init
  boot.initrd.systemd.enable = true;

  # hostname
  networking.hostName = hostName;
  
  # ssh
  services.openssh.enable = true;

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
     common = {
       default = [ "kde" "gtk" ];
       "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
     };
     hyprland = {
       default = [ "hyprland" "kde" "gtk" ];
       "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
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
  nixpkgs.overlays = [ inputs.millennium.overlays.default ];
  
  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "Bibata-Modern-Ice";
    HYPRCURSOR_SIZE = "24";
    QT_QPA_PLATFORMTHEME = "kde";
    GTK_USE_PORTAL = "1";
  };

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

  # virtualbox
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ username ];

  # stim
  programs.steam = {
    enable = true;
    package = pkgs.millennium-steam.override {
      extraPkgs = pkgs: [ pkgs.bibata-cursors ];
    };
    extraCompatPackages = [
      inputs.proton-ge.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.proton-cachyos.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
