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
    };

    config = {
      themeLinks = [
        "https://catppuccin.github.io/discord/dist/catppuccin-mocha-pink.theme.css"
      ];
      enabledThemeLinks = [
        "https://catppuccin.github.io/discord/dist/catppuccin-mocha-pink.theme.css"
      ];
    };
  };
}
