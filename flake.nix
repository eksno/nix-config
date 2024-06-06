{
  description = "Chronoverse Flake Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { nixpkgs, home-manager, hyprland, ... }: {
    nixosConfigurations = {
      # Teto's Work PC
      chuu = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
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
        system = "x86_64-linux";
        modules = [
          ./system/users/lucy
          ./system/hosts/lappy

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lucy = import ./home/users/lucy;
          }
        ];
      };

      # Lucy's Desktop
      chrono = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
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

      # Jonas' Main
      verse = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
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

      # Jonas' Other
      werse = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./system/users/eksno
          ./system/hosts/werse

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
        system = "x86_64-linux";
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
        system = "x86_64-linux";
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
        system = "x86_64-linux";
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
