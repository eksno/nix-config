{
  description = "Chronoverse Flake Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { nixpkgs, home-manager, hyprland, ... }: {
    nixosConfigurations = {
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
          ./system/users/lucy
          ./system/hosts/chrono

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lucy = import ./home/users/lucy;
          }
        ];
      };

      # Jonas' Desktop
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

      # Jonas' Laptop
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

      # Jorge's Desktop
      antopiahk = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./system/users/jorge
          ./system/hosts/antopiahk

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.jorge = import ./home/users/jorge;
          }
        ];
      };

      # WSL
      wsl = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./system/users/eksno/headless.nix
          ./system/hosts/wsl

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.nixos = import ./home/users/eksno/headless.nix;
          }
        ];
      };
    };
  };
}
