{ pkgs, ... }:
{
  # enable for kde plasma
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.printing.enable = true;

  # x11 server
  services.xserver.enable = true;
  
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "pl";
    variant = "";
  };

  # doas
  security.doas.enable = true;
  
  # delete unwanted pkgs
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    gwenview
    okular
  ];

  security.doas.extraRules = [
    {
    users = [ "moxiu" ];
    keepEnv = true;
    persist = true;
  }
 ];
}
