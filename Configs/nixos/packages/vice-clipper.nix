{ inputs }:
pkgs:
let
  lib = pkgs.lib;
  tools = with pkgs; [
    ffmpeg
    gpu-screen-recorder
    systemd
    wf-recorder
    wl-clipboard
    wmctrl
    xclip
    xdg-utils
    xdotool
    xprop
  ];
in
pkgs.python3Packages.buildPythonApplication {
  pname = "vice-clipper";
  version = "2.14.1";
  pyproject = true;

  src = inputs.vice;

  build-system = [ pkgs.python3Packages.setuptools ];

  dependencies = with pkgs.python3Packages; [
    aiohttp
    click
    evdev
    psutil
    pyqt6
    pyqt6-webengine
    pywebview
    qtpy
    tomli-w
  ];

  nativeBuildInputs = [ pkgs.qt6.wrapQtAppsHook ];

  buildInputs = [ pkgs.qt6.qtbase ];

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath tools)
  ];

  postInstall = ''
    install -Dm644 vice.desktop $out/share/applications/vice.desktop
    install -Dm644 assets/vice.svg $out/share/icons/hicolor/scalable/apps/vice.svg
    install -Dm644 packaging/vice.rules $out/lib/udev/rules.d/70-vice-input.rules
    install -Dm644 packaging/vice.service $out/lib/systemd/user/vice.service
    substituteInPlace $out/lib/systemd/user/vice.service \
      --replace-fail /usr/bin/vice $out/bin/vice
  '';

  pythonImportsCheck = [ "vice" ];

  meta = {
    description = "Medal.tv-style game clip recorder for Linux";
    homepage = "https://github.com/eklonofficial/Vice";
    license = lib.licenses.gpl3Plus;
    mainProgram = "vice-app";
    platforms = lib.platforms.linux;
  };
}
