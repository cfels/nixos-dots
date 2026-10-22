{ pkgs, ... }:
{
  dconf.settings."org/gnome/desktop/wm/preferences".button-layout = ":";

  programs.vscodium = {
    enable = true;
    profiles.default = {
      mutableUserSettings = true;
      userSettings = {
        "window.controlsStyle" = "hidden";
        "todo-tree.ripgrep" = "${pkgs.ripgrep}/bin/rg";
      };
    };
  };

  programs.librewolf = {
    enable = true;
    configPath = ".config/librewolf/librewolf";
    profiles.default = {
      path = "s8ther0f.default";
      userChrome = ''
        .titlebar-buttonbox-container,
        #window-controls {
          display: none !important;
        }
      '';
    };
  };
}
