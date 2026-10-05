{ lib, pkgs, ... }:
let
  kdeColorsApply = pkgs.writeShellApplication {
    name = "kde-colors-apply";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${pkgs.writeText "kde-colors-apply.py" ''
        import os
        import sys
        import time

        home = os.path.expanduser("~")
        config_home = os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config")
        scheme_path = os.path.join(home, ".local/share/color-schemes/Matugen.colors")
        globals_path = os.path.join(config_home, "kdeglobals")

        if not os.path.isfile(scheme_path):
            sys.exit(0)


        def parse(text):
            order = []
            data = {}

            for raw in text.splitlines():
                line = raw.strip()

                if not line:
                    continue

                if line.startswith("[") and line.endswith("]"):
                    name = line[1:-1]
                    if name not in data:
                        data[name] = []
                        order.append(name)
                    continue

                if "=" not in line or not order:
                    continue

                key, value = line.split("=", 1)
                data[order[-1]].append([key.strip(), value.strip()])

            return order, data


        def set_key(order, data, group, key, value):
            if group not in data:
                data[group] = []
                order.append(group)

            for entry in data[group]:
                if entry[0] == key:
                    entry[1] = value
                    return

            data[group].append([key, value])


        with open(scheme_path, encoding="utf-8") as handle:
            scheme_order, scheme = parse(handle.read())

        try:
            with open(globals_path, encoding="utf-8") as handle:
                order, current = parse(handle.read())
        except FileNotFoundError:
            order, current = [], {}

        for group in scheme_order:
            if not (
                group.startswith("Colors:")
                or group.startswith("ColorEffects:")
                or group == "WM"
            ):
                continue

            for key, value in scheme[group]:
                set_key(order, current, group, key, value)

        set_key(order, current, "General", "ColorScheme", "Matugen")
        set_key(order, current, "General", "ColorSchemeHash", str(int(time.time())))

        lines = []

        for group in order:
            lines.append("[" + group + "]")

            for key, value in current[group]:
                lines.append(key + "=" + value)

            lines.append("")

        with open(globals_path, "w", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
      ''}
    '';
  };
in {
  qt = {
    enable = true;
    platformTheme = "kde";
    style = "breeze";
  };

  environment.systemPackages = with pkgs; [
    kdeColorsApply
    kdePackages.plasma-integration.qt5
    kdePackages.breeze-icons
    kdePackages.breeze-gtk
    kdePackages.qqc2-desktop-style
    kdePackages.qqc2-breeze-style
    kdePackages.libplasma
    kdePackages.kirigami
    kdePackages.kiconthemes
    kdePackages.kconfig
    kdePackages.kfilemetadata
    kdePackages.frameworkintegration
    kdePackages.kio-extras
    kdePackages.kimageformats
    kdePackages.qtimageformats
    kdePackages.qtsvg
    kdePackages.kde-gtk-config
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    hack-font
  ];

  fonts.fontconfig.defaultFonts = {
    monospace = [ "Hack" "Noto Sans Mono" ];
    sansSerif = [ "Noto Sans" ];
    serif = [ "Noto Serif" ];
    emoji = [ "Noto Color Emoji" ];
  };

  xdg.icons.fallbackCursorThemes = lib.mkDefault [ "breeze_cursors" ];

  systemd.user.services.plasma-xdg-desktop-portal-kde = {
    description = "Xdg Desktop Portal For KDE";
    partOf = [ "graphical-session.target" ];
    environment = {
      QT_QPA_PLATFORMTHEME = "kde";
      QT_STYLE_OVERRIDE = "breeze";
      QT_PLUGIN_PATH = "${pkgs.kdePackages.plasma-integration}/lib/qt-6/plugins:/run/current-system/sw/lib/qt-6/plugins";
    };
    serviceConfig = {
      Type = "dbus";
      BusName = "org.freedesktop.impl.portal.desktop.kde";
      ExecStart = "${pkgs.kdePackages.xdg-desktop-portal-kde}/libexec/xdg-desktop-portal-kde";
      Slice = "session.slice";
      Restart = "no";
    };
  };
}
