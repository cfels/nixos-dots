{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.vice-clipper ];

  services.udev.packages = [ pkgs.vice-clipper ];

  systemd.user.services.vice = {
    description = "Vice game clip recorder daemon";
    documentation = [ "https://github.com/eklonofficial/Vice" ];
    after = [ "graphical-session.target" ];
    wantedBy = [
      "graphical-session.target"
      "default.target"
    ];
    unitConfig = {
      StartLimitIntervalSec = 60;
      StartLimitBurst = 3;
    };
    serviceConfig = {
      ExecStart = "${pkgs.vice-clipper}/bin/vice start --no-open-ui";
      Restart = "on-failure";
      RestartSec = 3;
      PassEnvironment = [
        "WAYLAND_DISPLAY"
        "DISPLAY"
        "XDG_RUNTIME_DIR"
        "DBUS_SESSION_BUS_ADDRESS"
        "XDG_SESSION_TYPE"
        "XDG_CURRENT_DESKTOP"
      ];
    };
  };
}
