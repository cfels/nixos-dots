{
  lib,
  coreutils,
  systemd,
  writeShellApplication,
  helium,
}:
let
  session = writeShellApplication {
    name = "helium-session";
    runtimeInputs = [ coreutils ];
    text = ''
      : "''${XDG_RUNTIME_DIR:?Helium requires a desktop user session}"

      # Keep the handoff socket shared across launchers with private /tmp mounts.
      export TMPDIR="$XDG_RUNTIME_DIR/helium"
      install -d -m 700 "$TMPDIR"

      exec ${helium}/bin/helium "$@"
    '';
  };
  launcher = writeShellApplication {
    name = "helium";
    runtimeInputs = [ systemd ];
    text = ''
      # The session manager supplies the environment and owns the browser lifetime.
      exec systemd-run --user --collect --quiet --wait \
        --service-type=exec --expand-environment=no \
        -- ${lib.getExe session} "$@"
    '';
  };
in
launcher.overrideAttrs (old: {
  buildCommand = old.buildCommand + ''
    cp -r ${helium}/share "$out/share"
    chmod u+w "$out/share/applications/helium.desktop"
    substituteInPlace "$out/share/applications/helium.desktop" \
      --replace-fail 'Exec=helium' "Exec=$out/bin/helium"
  '';
})
