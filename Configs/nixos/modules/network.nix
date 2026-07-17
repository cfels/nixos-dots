{ config, pkgs, ... }:
{
    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # enable networking
    systemd.services.NetworkManager-wait-online.enable = false;
    networking.networkmanager.enable = true;
    networking.firewall.allowedTCPPorts = [ 22 25565 ];
}
