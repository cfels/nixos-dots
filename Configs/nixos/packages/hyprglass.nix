{ inputs }:
pkgs:
pkgs.hyprlandPlugins.mkHyprlandPlugin rec {
  pluginName = "hyprglass";
  version = "1.1.0";

  src = inputs.hyprglass;

  makeFlags = [ "HYPRGLASS_VERSION=${version}" ];

  nativeBuildInputs = [
    pkgs.gnumake
    pkgs.wayland-scanner
  ];

  buildInputs = [
    pkgs.pixman
    pkgs.wayland
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 hyprglass.so $out/lib/hyprglass.so
    runHook postInstall
  '';

  meta = {
    description = "Apple-style Liquid Glass effect for Hyprland";
    homepage = "https://github.com/hyprnux/hyprglass";
    license = pkgs.lib.licenses.bsd3;
    mainProgram = "hyprglass";
    platforms = pkgs.lib.platforms.linux;
  };
}
