{
    description = "Moxi's VacOS configuration";

    inputs = {
      nixcord.url = "github:FlameFlag/nixcord";
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
      fagram.url = "github:cfels/fadesktop";
      codex.url = "github:SecBear/codex-nix";
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
    };

    outputs = inputs@{ self, nixpkgs, home-manager, kwin-better-blur-dx, ... }:
    let
      system = "x86_64-linux";

      vice-clipper = pkgs:
        let
          lib = pkgs.lib;
          tools = with pkgs; [
            cloudflared
            ffmpeg
            gpu-screen-recorder
            systemd
            wf-recorder
            wl-clipboard
            wmctrl
            xclip
            xdg-utils
            xdotool
            xprop
          ];
        in
        pkgs.python3Packages.buildPythonApplication {
          pname = "vice-clipper";
          version = "2.13.0";
          pyproject = true;

          src = inputs.vice;

          build-system = [ pkgs.python3Packages.setuptools ];

          dependencies = with pkgs.python3Packages; [
            aiohttp
            click
            evdev
            psutil
            pyqt6
            pyqt6-webengine
            pywebview
            qtpy
            tomli-w
          ];

          nativeBuildInputs = [ pkgs.qt6.wrapQtAppsHook ];

          buildInputs = [ pkgs.qt6.qtbase ];

          makeWrapperArgs = [
            "--prefix PATH : ${lib.makeBinPath tools}"
          ];

          postInstall = ''
            install -Dm644 vice.desktop $out/share/applications/vice.desktop
            install -Dm644 assets/vice.svg $out/share/icons/hicolor/scalable/apps/vice.svg
            install -Dm644 packaging/vice.rules $out/lib/udev/rules.d/70-vice-input.rules
            install -Dm644 packaging/vice.service $out/lib/systemd/user/vice.service
            substituteInPlace $out/lib/systemd/user/vice.service \
              --replace-fail /usr/bin/vice $out/bin/vice
          '';

          pythonImportsCheck = [ "vice" ];

          meta = {
            description = "Medal.tv-style game clip recorder for Linux";
            homepage = "https://github.com/eklonofficial/Vice";
            license = lib.licenses.gpl3Plus;
            mainProgram = "vice-app";
            platforms = lib.platforms.linux;
          };
        };

      viceOverlay = final: prev: {
        vice-clipper = vice-clipper prev;
      };
    in {
      packages.${system} = {
        vice-clipper = vice-clipper nixpkgs.legacyPackages.${system};
        default = vice-clipper nixpkgs.legacyPackages.${system};
      };

      overlays.default = viceOverlay;

      nixosModules.vice =
        { pkgs, ... }:
        {
          environment.systemPackages = [ pkgs.vice-clipper ];

          services.udev.packages = [ pkgs.vice-clipper ];

          systemd.user.services.vice = {
            description = "Vice game clip recorder daemon";
            documentation = [ "https://github.com/eklonofficial/Vice" ];
            after = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" "default.target" ];
            unitConfig = {
              StartLimitIntervalSec = 60;
              StartLimitBurst = 3;
            };
            serviceConfig = {
              ExecStart = "${pkgs.vice-clipper}/bin/vice start --no-open-ui";
              Restart = "on-failure";
              RestartSec = 3;
              PassEnvironment = [
                "WAYLAND_DISPLAY"
                "DISPLAY"
                "XDG_RUNTIME_DIR"
                "DBUS_SESSION_BUS_ADDRESS"
                "XDG_SESSION_TYPE"
                "XDG_CURRENT_DESKTOP"
              ];
            };
          };
        };

      nixosConfigurations.moxiu = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          { nixpkgs.overlays = [ viceOverlay ]; }
          self.nixosModules.vice
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
                ];
              };
            };
          }
        ];
      };
    };
  }
