{ pkgs, ... }:
{
  dconf.settings."org/gnome/desktop/wm/preferences".button-layout = ":";

  xdg.configFile."millennium/quick.css".text = ''
    .title-bar-actions.window-controls {
      display: none !important;
    }
  '';

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
}
