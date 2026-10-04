{ config, pkgs, lib, username, ... }: 
{
  imports = [
    ./pkgs.nix
    ./git.nix
    ./nixcord.nix
  ];

  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
