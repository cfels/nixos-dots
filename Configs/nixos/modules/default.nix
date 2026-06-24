{ config, pkgs, ... }: {
  imports = [
    ./sddm.nix
    ./bootloader.nix
    ./locales.nix
    ./misc.nix
    ./network.nix
    ./pkgs.nix
    ./services.nix
    ./sound.nix
    ./users.nix
    ./setting.nix
    ./home.nix
    ./docker.nix
  ];
}
