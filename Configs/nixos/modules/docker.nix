{ pkgs, username, ... }:
{
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
  users.users.${username}.extraGroups = [ "docker" ];
}
