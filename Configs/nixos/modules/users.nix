{ pkgs, username, ... }:
{
# define user
  users.mutableUsers = true;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" "video" "render" ];
    shell = pkgs.fish;
  };
}
