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
    
    pointerCursor = {
      enable = true;
      name = "Bibata-Modern-Ice";
      size = 24;
      package = lib.mkForce pkgs.bibata-cursors;
      gtk.enable = true;
      x11.enable = true;
    };
  };

  programs.home-manager.enable = true;
}
