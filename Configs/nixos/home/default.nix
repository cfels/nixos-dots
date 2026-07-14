{ config, pkgs, lib, ... }: 
{
  imports = [
    ./pkgs.nix
    ./git.nix
  ];

  home = {
    username = "moxiu";
    homeDirectory = "/home/moxiu";
    stateVersion = "24.11";
  };

  home.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "qt6ct";
  };

  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Dark";
      package = null; 
    };
    iconTheme = {
      name = "WhiteSur-dark";
      package = null; 
    };
    gtk4.theme = config.gtk.theme;
  };
 
  xdg.configFile."gtk-3.0/settings.ini".force = true;
  xdg.configFile."gtk-4.0/settings.ini".force = true;

  home.file = {
    ".config/hypr" = { source = ../../../Configs/config/hypr; recursive = true; };
    ".config/kitty" = { source = ../../../Configs/config/kitty; recursive = true; };

    "Pictures/walls" = {
      source = ../../../Configs/walls;
      recursive = true;
    };
  };

  programs.home-manager.enable = true;
}
