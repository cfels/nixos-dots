{ pkgs, ... }:
{
# define user
  users.users."moxiu" = {
    isNormalUser = true;
    description = "moxiu";
    extraGroups = [ "networkmanager" "wheel" "video" "render" ];
    shell = pkgs.fish;
  };
}
