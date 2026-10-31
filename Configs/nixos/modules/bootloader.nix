{ config, pkgs, lib, ... }:

{
  imports = [ ./grub-secure-snapshot.nix ];

  boot.plymouth = {
    enable = true;
    showDelay = 0;
    plymouth-minecraft-theme.enable = true;
  };

  # Keep boot messages from covering the Plymouth loading screen.
  boot.consoleLogLevel = 0;
  boot.kernelParams = [ "quiet" ];

  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
    };
    grub = {
      enable = true;
      signedSnapshot.enable = true;
      efiSupport = true;
      device = "nodev";
      # The signed snapshot supports NixOS entries, not external chainloaders.
      useOSProber = false;
      configurationLimit = 3;
      # Leave Minegrub's framed terminal before loading the kernel/initrd.
      # Plymouth takes over once Linux has initialized the display.
      extraPerEntryConfig = ''
        terminal_output console
        clear
      '';
      # Keep the Minecraft main menu enabled whenever GRUB is regenerated.
      extraInstallCommands = ''
        ${pkgs.grub2}/bin/grub-editenv /boot/grub/grubenv set config_file=mainmenu.cfg
      '';
      double-minegrub-menu = {
        enable = true;
        main_menu_background = "1.8  - [Classic Minecraft].png";
        splash_text = "100% Declarative";
        world_selection_background_scaled = "1366x768";
        world_selection_custom_icons = with config.system; [
          {
            inherit name;
            lineTop = with nixos; distroName + " " + codeName + " (" + version + ")";
            lineBottom = "Survival Mode, No Cheats, Version: " + nixos.release;
            imgName = "nixos";
          }
        ];
      };
    };
    timeout = 30;
  };

  # decrypt partitions
  boot.initrd.luks.devices = import ../luks.nix;
}
