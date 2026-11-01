{
  description = "Moxi's VacOS configuration";

  inputs = {
    minecraft-plymouth-theme = {
      url = "github:nikp123/minecraft-plymouth-theme";
      flake = false;
    };
    double-minegrub-menu = {
      url = "github:Lxtharia/double-minegrub-menu/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixcord.url = "github:FlameFlag/nixcord";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:AlvaroParker/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fagram = {
      url = "github:cfels/fadesktop";
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
      url = "github:splitshotz/Vice";
      inputs.nixpkgs.follows = "nixpkgs";
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
      url = "github:hyprnux/hyprglass/85b8a8ed8431d7b6f1ef8dad8ae0470d8ea7f291";
      flake = false;
    };
    omikuji = {
      url = "github:omikuji-launcher/omikuji";
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
      umadance,
      ...
    }:
    let
      system = "x86_64-linux";
      username = import ./username.nix;
      hostName = import ./hostname.nix;

      hyprglass-plugin = import ./packages/hyprglass.nix { inherit inputs; };
    in
    {
      packages.${system} = {
        vice-clipper = inputs.vice.packages.${system}.vice-clipper;
        hyprglass = hyprglass-plugin nixpkgs.legacyPackages.${system};
        default = inputs.vice.packages.${system}.default;
      };

      overlays.default = import ./overlays/default.nix;

      nixosModules.vice = inputs.vice.nixosModules.default;

      nixosConfigurations.${username} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs username hostName; };
        modules = [
          (inputs.minecraft-plymouth-theme + "/nixos.nix")
          inputs.double-minegrub-menu.nixosModules.default
          ./configuration.nix
          {
            nixpkgs.overlays = [ self.overlays.default ];
            services.vice.enable = true;
          }
          self.nixosModules.vice
          umadance.nixosModules.default
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
