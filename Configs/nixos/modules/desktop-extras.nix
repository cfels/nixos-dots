{ hyprglass-plugin }:
{ lib, pkgs, ... }:
{
  programs.twintaillauncher.enable = true;
  programs.gamescope.enable = lib.mkForce true;
  programs.umadance.enable = true;

  environment.etc."hypr/hyprglass.so".source = "${hyprglass-plugin pkgs}/lib/hyprglass.so";
}
