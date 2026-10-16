{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  home.packages = with pkgs; [
    inputs.codex-cli.packages.${pkgs.system}.default
    inputs.fagram.packages.x86_64-linux.default
    inputs.pineconemc.packages.${system}.prismlauncher
    (inputs.seanime.packages.${pkgs.stdenv.hostPlatform.system}.seanime-denshi.overrideAttrs (
      oldAttrs:
      let
        appimageContents = pkgs.appimageTools.extract {
          inherit (oldAttrs) pname version src;
        };
      in
      {
        installPhase =
          builtins.replaceStrings
            [ "Type=Applicaiton" "Categories=Network;Player;TV;Video;" "Icon=seanime\n" ]
            [
              "Type=Application"
              "Categories=AudioVideo;Player;TV;Video;"
              "Icon=$out/share/pixmaps/seanime-denshi.png\n"
            ]
            oldAttrs.installPhase
          + ''
            install -Dm644 ${appimageContents}/seanime-denshi.png "$out/share/pixmaps/seanime-denshi.png"
          '';
      }
    ))
    bubblewrap
    btop
    ripgrep
    fd
    fzf
    lazygit
    unzip
    wget
    noto-fonts
    noto-fonts-cjk-sans
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
    lazygit
  ];

  # Font configuration
  fonts.fontconfig.enable = true;
}
