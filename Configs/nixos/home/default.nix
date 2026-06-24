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
  
  programs.librewolf = {
    enable = true;
    profiles.moxiu = {
      isDefault = true;
      id = 0;
      name = "moxiu";
      path = "moxiu.default";
      settings = {
        "browser.startup.homepage" = "about:newtab";
        "extensions.activeThemeID" = "FirefoxColor@mozilla.com";
        "webgl.disabled" = false;

        "ExtensionSettings" = {
          "uBlock0@raymondhill.net" = {
            "installation_mode" = "force_installed";
            "install_url" = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          };
          "{73a6fe31-595d-460b-a920-fcc0f8843232}" = {
            "installation_mode" = "force_installed";
            "install_url" = "https://addons.mozilla.org/firefox/downloads/latest/styl-us/latest.xpi";
          };
          "extension@tabliss.io" = {
            "installation_mode" = "force_installed";
            "install_url" = "https://addons.mozilla.org/firefox/downloads/latest/tabliss/latest.xpi";
          };
        };
      };
    };
  };

  home.file = {
    ".config/hypr" = { source = ../../../Configs/.config/hypr; recursive = true; };
    ".config/kitty" = { source = ../../../Configs/.config/kitty; recursive = true; };
    
    "Pictures/walls" = {
      source = ../../../Configs/walls;
      recursive = true;
    };
  };

  programs.home-manager.enable = true;
}
