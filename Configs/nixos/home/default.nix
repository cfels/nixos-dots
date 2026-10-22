{
  config,
  pkgs,
  lib,
  username,
  ...
}:

{
  imports = [
    ./pkgs.nix
    ./git.nix
    ./nixcord.nix
    ./window-controls.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.05";

    pointerCursor = {
      enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
      x11.enable = true;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    cursor-theme = config.home.pointerCursor.name;
    cursor-size = config.home.pointerCursor.size;
  };

  xdg.configFile."kcminputrc".text = ''
    [Mouse]
    cursorTheme=${config.home.pointerCursor.name}
    cursorSize=${toString config.home.pointerCursor.size}
  '';

  services.xsettingsd.enable = true;

  systemd.user.services.xsettingsd.Service = {
    ExecStartPre = [
      "${lib.getExe pkgs.xrdb} -merge ${config.xresources.path}"
      "${lib.getExe pkgs.xsetroot} -xcf ${config.home.pointerCursor.package}/share/icons/${config.home.pointerCursor.name}/cursors/${config.home.pointerCursor.x11.defaultCursor} ${toString config.home.pointerCursor.size}"
    ];

    ExecStart = lib.mkForce "${lib.getExe pkgs.xsettingsd} -c ${config.xdg.configHome}/xsettingsd/xsettingsd.conf";
  };

  programs.home-manager.enable = true;
}
