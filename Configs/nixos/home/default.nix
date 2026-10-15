{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}:
let
  codexDesktop = inputs.codex-app.packages.${pkgs.stdenv.hostPlatform.system}.codex-desktop;
in
{
  imports = [
    ./pkgs.nix
    ./git.nix
    ./nixcord.nix
  ];

  home = {
    username = username;
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

  programs.codexDesktopLinux = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "${codexDesktop.name}-auto-ozone";
      paths = [ codexDesktop ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        rm "$out/bin/codex-desktop"
        makeWrapper "${codexDesktop}/bin/codex-desktop" "$out/bin/codex-desktop" \
          --set-default CODEX_OZONE_PLATFORM auto
        desktopFile="$out/share/applications/codex-desktop.desktop"
        rm "$desktopFile"
        substitute "${codexDesktop}/share/applications/codex-desktop.desktop" "$desktopFile" \
          --replace-fail "${codexDesktop}/bin/codex-desktop" "$out/bin/codex-desktop"
      '';
      meta = codexDesktop.meta;
    };
  };
  programs.home-manager.enable = true;
}
