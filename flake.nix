{
  description = "Chronoverse Flake Config";

  inputs = {
    hyprland.url = "github:hyprwm/Hyprland";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };


  outputs = inputs: let
        nixpkgs = inputs.nixpkgs;
        home-manager = inputs.home-manager;
        system = "x86_64-linux";
        pkgs = import inputs.nixpkgs {
            inherit system;
            config = {
                permittedInsecurePackages = [];
                allowUnfree = true;
                packageOverrides = pkgs: {
                    intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
                    # catppuccin-gtk = pkgs.catppuccin-gtk.override {
                    #     size = "standard";
                    #     variant = "mocha";
                    # };
                };
            };
        };
  in {
    nixosConfigurations = {
      # Teto's Work PC
      chuu = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs pkgs;};
        modules = [
          ./system/users/nabi
          ./system/hosts/chuu

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.nabi = import ./home/users/nabi;
          }
        ];
      };

      # Lucy's Laptop
      lappy = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs pkgs;};
        modules = [
          ./system/users/teto
          ./system/hosts/lappy

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.teto = import ./home/users/teto;
          }
        ];
      };

      # Lucy's Desktop
      chrono = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs pkgs;};
        modules = [
          ./system/users/teto
          ./system/hosts/chrono

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.teto = import ./home/users/teto;
          }
        ];
      };

      # Biwas' Main
      ace = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs pkgs;};
        modules = [
          ./system/users/biwas
          ./system/hosts/ace

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.biwas = import ./home/users/biwas;
          }
        ];
      };

      # Jonas' Main
      verse = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs pkgs;};
        modules = [
          ./system/users/eksno
          ./system/hosts/verse

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.eksno = import ./home/users/eksno;
          }
        ];
      };

      # Jorge's Laptop
      lewis = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs pkgs;};
        modules = [
          ./system/users/jorge
          ./system/hosts/lewis

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.jorge = import ./home/users/jorge;
          }
        ];
      };

      # WSL
      eksno-wsl = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs pkgs;};
        modules = [
          ./system/users/eksno/headless.nix
          ./system/hosts/eksno-wsl

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.nixos = import ./home/users/eksno/headless.nix;
          }
        ];
      };

      # WSL
      leon-wsl = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs pkgs;};
        modules = [
          ./system/users/leon/headless.nix
          ./system/hosts/leon-wsl

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.nixos = import ./home/users/leon/headless.nix;
          }
        ];
      };
    };
  };
}
