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

      # Daniel's Desktop
      chrono = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./system/shared/main.nix
          ./system/users/calibor
          ./system/hosts/chrono

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.calibor = import ./home/users/calibor;

            # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
          }
        ];
      };

      # Jonas' Desktop
      verse = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./system/shared/main.nix
          ./system/shared/nvidia.nix
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

      # Jonas' Virtualbox
      virteks = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./system/shared/main.nix
          ./system/shared/nvidia.nix
          ./system/users/eksno
          ./system/hosts/virteks

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.eksno = import ./home/users/eksno;

            # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
          }
        ];
      };
    };
  };
}
