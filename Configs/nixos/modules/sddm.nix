{ config, lib, pkgs, ... }:
let
  custom-sddm-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "hyprland_kath";
  };
in {
  boot.initrd.kernelModules = [ "amdgpu" ];
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  boot.kernelParams = [
    "initcall_blacklist=simpledrm_platform_driver_init"
    "amdgpu.ppfeaturemask=0xffffffff"
    "amdgpu.dc=1"
  ];
  services.libinput = {
    enable = true;
    mouse = {
      accelSpeed = "-0.8";
      accelProfile = "flat";
    };
  };
  services.displayManager.sddm = {
    enable = true;
    wayland = {
      enable = true;
      compositor = "kwin";
    };
    autoNumlock = true;
    enableHidpi = true;
    theme = "sddm-astronaut-theme";
    settings = {
      General = {
        DisplayServer = "wayland";
        CursorTheme = "Bibata-Modern-Ice";
        CursorSize = "24";
      };
      Theme = {
        Current = "sddm-astronaut-theme";
        CursorTheme = "Bibata-Modern-Ice";
        CursorSize = 24;
      };
      Wayland.CompositorCommand = lib.mkForce "${pkgs.kdePackages.kwin}/bin/kwin_wayland --no-global-shortcuts --no-kactivities --no-lockscreen --locale1";
    };
    extraPackages = with pkgs; [
      custom-sddm-astronaut
      kdePackages.kwin
      bibata-cursors
      kdePackages.qtmultimedia
    ];
  };
  environment.systemPackages = [ custom-sddm-astronaut ];
  environment.etc."xdg/kwinrc".text = ''
    [Plugins]
    shakecursorEnabled=false
  '';
  environment.etc."xdg/kcminputrc".text = ''
    [Mouse]
    PointerAcceleration=-0.500
    PointerAccelerationProfile=1
  '';
}
