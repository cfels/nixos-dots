{ pkgs, ... }:
{
# define user
  users.users."moxiu" = {
    isNormalUser = true;
    description = "moxiu";
    extraGroups = [ "networkmanager" "wheel" "video" "render" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
    shell = pkgs.fish;
  };
}
