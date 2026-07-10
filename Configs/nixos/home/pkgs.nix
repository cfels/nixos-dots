{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    inputs.fagram.packages.x86_64-linux.default
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