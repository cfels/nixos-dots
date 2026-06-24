{ config, pkgs, ... }:
{
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "daily";
      extraArgs = "--keep 3"; # keep current + 2 older
    };
  };

  nix.gc.automatic = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  nix.settings.trusted-users = [ "root" "moxiu" ];
}
