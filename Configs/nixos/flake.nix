{
  description = "Moxi's VacOS configuration";

  inputs = {
    nixcord.url = "github:FlameFlag/nixcord";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    fagram = {
      url = "github:cfels/fadesktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pineconemc = {
      url = "github:ElyPrismLauncher/Launcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    millennium.url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
    proton-ge = {
      url = "github:Daaboulex/proton-ge-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    proton-cachyos = {
      url = "github:Daaboulex/proton-cachyos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vice = {
      url = "github:eklonofficial/Vice";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kwin-better-blur-dx = {
      url = "github:xarblu/kwin-effects-better-blur-dx";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprglass = {
      url = "github:hyprnux/hyprglass/84c1a5ab217101a317d4edaab7fba2efcc1bf346";
      flake = false;
    };
    twintail-nix = {
      url = "github:madebycli/twintail-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    umadance = {
      url = "github:cfels/umadance";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    seanime = {
      url = "github:cfels/seanime-nix/49dd0f5015e3047296a2ba23f680478c15e052ba";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      kwin-better-blur-dx,
      twintail-nix,
      umadance,
      ...
    }:
    let
      system = "x86_64-linux";
      username = import ./username.nix;
      hostName = import ./hostname.nix;

      vice-clipper = import ./packages/vice-clipper.nix { inherit inputs; };
      viceOverlay = import ./overlays/default.nix { inherit vice-clipper; };
      hyprglass-plugin = import ./packages/hyprglass.nix { inherit inputs; };
    in
    {
      packages.${system} = {
        vice-clipper = vice-clipper nixpkgs.legacyPackages.${system};
        hyprglass = hyprglass-plugin nixpkgs.legacyPackages.${system};
        default = vice-clipper nixpkgs.legacyPackages.${system};
      };

      overlays.default = viceOverlay;

      nixosModules.vice = import ./modules/vice.nix;

      nixosConfigurations.${username} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs username hostName; };
        modules = [
          ./configuration.nix
          { nixpkgs.overlays = [ viceOverlay ]; }
          self.nixosModules.vice
          umadance.nixosModules.default
          twintail-nix.nixosModules.default
          (import ./modules/desktop-extras.nix { inherit hyprglass-plugin; })
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = { inherit inputs username hostName; };
              users.${username} = {
                imports = [
                ];
              };
            };
          }
        ];
      };
    };
}
