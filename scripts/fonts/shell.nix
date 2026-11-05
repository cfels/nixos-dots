let
  flake = builtins.getFlake (toString ../../Configs/nixos);
  pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
in
pkgs.mkShell {
  packages = [
    (pkgs.python3.withPackages (p: [
      p.fonttools
      p.brotli
      p.uharfbuzz
    ]))
  ];
}
