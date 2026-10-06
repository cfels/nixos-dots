{ config, inputs, pkgs, lib, username, ... }:
{
# my gpu drivers
  hardware.graphics = {
  enable = true;
  enable32Bit = true;
  extraPackages = with pkgs; [
    amdvlk
    vaapiVdpau
    libvdpau-va-gl
    rocmPackages.rocm-smi
  ];
};

services.xserver.videoDrivers = [ "amdgpu" ];

users.users.${username}.extraGroups = [ "video" "render" ];
}
