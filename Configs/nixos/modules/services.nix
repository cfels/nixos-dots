{ pkgs, username, ... }:
{
  # enable for kde plasma
  services.displayManager.sddm.enable = true;
  services.printing.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  # x11 server
  services.xserver.enable = true;
  
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "pl";
    variant = "";
  };

  # doas
  security.doas.enable = true;
  
  xdg.mime.defaultApplications = {
    "inode/directory" = "org.kde.dolphin.desktop";
  };

  security.doas.extraRules = [
    {
    users = [ username ];
    keepEnv = true;
    persist = true;
  }
 ];
}
