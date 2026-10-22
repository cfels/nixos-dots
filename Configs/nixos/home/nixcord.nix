{ inputs, ... }:
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
      themes.window-controls = ''
        [data-window-chrome="true"] {
          margin-inline-end: 12px !important;
        }

        [class*="winButtons_"] {
          display: none !important;
        }
      '';
      enabledThemes = [ "window-controls.css" ];
    };
  };
}
