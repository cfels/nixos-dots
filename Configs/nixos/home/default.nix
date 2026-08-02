{ config, pkgs, lib, ... }: 
{
  imports = [
    ./pkgs.nix
    ./git.nix
    ./nixcord.nix
  ];

  home = {
    username = "moxiu";
    homeDirectory = "/home/moxiu";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
