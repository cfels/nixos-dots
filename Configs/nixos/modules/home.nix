{ config, pkgs, inputs, ... }:
{
  imports = [ 
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users = {
      moxiu = import ../home/default.nix;
    };
  };  
}
