{ inputs, pkgs, ... }:
let
  windowControlsTheme = pkgs.writeText "window-controls.css" ''
    [data-window-chrome="true"] {
      margin-inline-end: 12px !important;
    }

    [class*="winButtons_"] {
      display: none !important;
    }
  '';
in
{
  imports = [
    inputs.nixcord.homeModules.nixcord
    ./nixcord-plugins.nix
  ];

  programs.nixcord = {
    enable = true;

    discord = {
      enable = true;
      installPackage = true;
      branches = [ "stable" ];
      equicord.enable = true;
      krisp.enable = true;
    };

    config = {
      themeLinks = [
        "https://catppuccin.github.io/discord/dist/catppuccin-mocha-pink.theme.css"
      ];
      enabledThemeLinks = [
        "https://catppuccin.github.io/discord/dist/catppuccin-mocha-pink.theme.css"
      ];
      themes.window-controls = windowControlsTheme;
      enabledThemes = [ "window-controls.css" ];
    };
  };

  home.file.".config/Equicord/themes/window-controls.css".source = windowControlsTheme;
}
