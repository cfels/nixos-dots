{ config, pkgs, inputs, username, hostName, ... }:
{
  imports = [ 
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs username hostName; };
    users = {
      ${username} = import ../home/default.nix;
    };
  };  
}
