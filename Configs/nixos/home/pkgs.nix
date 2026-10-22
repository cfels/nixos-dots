{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  fagram = inputs.fagram.packages.x86_64-linux.default;
  fagramWithNativeFrame = fagram.override {
    unwrapped = fagram.unwrapped.overrideAttrs (oldAttrs: {
      postPatch = (oldAttrs.postPatch or "") + ''
        substituteInPlace Telegram/SourceFiles/core/core_settings.cpp \
          --replace-fail '_nativeWindowFrame = (nativeWindowFrame == 1);' '_nativeWindowFrame = true;'
      '';
    });
  };
in
{
  home.packages = with pkgs; [
    fagramWithNativeFrame
    inputs.pineconemc.packages.${pkgs.stdenv.hostPlatform.system}.prismlauncher
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
