{
  description = "Moxi's VacOS configuration";

  inputs = { 
    nixcord.url = "github:FlameFlag/nixcord";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    fagram.url = "github:cfels/fadesktop";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kwin-better-blur-dx = {
    url = "github:xarblu/kwin-effects-better-blur-dx";
    inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, kwin-better-blur-dx, ... }: {
    nixosConfigurations.moxiu = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            extraSpecialArgs = { inherit inputs; };
            users.moxiu = {
              imports = [ 
                ./home/default.nix
                inputs.nixcord.homeModules.nixcord 
              ];
            };
          };
        }
      ];
    };
  };
}
