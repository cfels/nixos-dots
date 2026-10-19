{ username, ... }:
{
  services.displayManager.sddm.enable = true;
  services.printing.enable = true;
  services.udisks2.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  services.xserver.enable = true;

  services.xserver.xkb = {
    layout = "pl";
    variant = "";
  };

  security.doas.enable = true;

  xdg.mime.defaultApplications = {
    "inode/directory" = "org.kde.dolphin.desktop";
    "application/x-bittorrent" = "org.qbittorrent.qBittorrent.desktop";
    "x-scheme-handler/magnet" = "org.qbittorrent.qBittorrent.desktop";
  };

  security.doas.extraRules = [
    {
      users = [ username ];
      keepEnv = true;
      setEnv = [ "-XDG_CACHE_HOME" ];
      persist = true;
    }
  ];
}
