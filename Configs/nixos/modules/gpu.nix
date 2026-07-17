{ config, inputs, pkgs, lib, ... }:
{
# my gpu drivers
  hardware.graphics = {
  enable = true;
  enable32Bit = true;
  extraPackages = with pkgs; [
    amdvlk
    vaapiVdpau
    libvdpau-va-gl
  ];
};

services.xserver.videoDrivers = [ "amdgpu" ];

users.users.yourname.extraGroups = [ "video" "render" ];
}
