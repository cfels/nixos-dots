{ hyprglass-plugin }:
{ lib, pkgs, ... }:
{
  programs = {
    twintaillauncher.enable = true;
    gamescope.enable = lib.mkForce true;
    umadance.enable = true;
  };

  environment.etc."hypr/hyprglass.so".source = "${hyprglass-plugin pkgs}/lib/hyprglass.so";
}
