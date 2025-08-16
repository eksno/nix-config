{
  description = "Chronoverse Flake Config";

  inputs = {
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs:
    let
      sources = import ./npins;
      nixpkgs = inputs.nixpkgs;
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ ];
          packageOverrides = pkgs: {
            intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
          };
        };
      };
    in
    {
      nixosConfigurations = {
        # Teto's Work PC
        chuu = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs pkgs; };
          modules = [
            ./system/users/nabi
            ./system/hosts/chuu
          ];
        };

        # Lucy's Laptop
        lappy = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs pkgs; };
          modules = [
            ./system/users/teto
            ./system/hosts/lappy
          ];
        };

        # Lucy's Desktop
        chrono = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs pkgs; };
          modules = [
            ./system/users/teto
            ./system/hosts/chrono
          ];
        };

        # Biwas' Main
        ace = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs pkgs; };
          modules = [
            ./system/users/biwas
            ./system/hosts/ace
          ];
        };

        # Jonas' Main
        verse = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit
              system
              inputs
              ;
          };
          pkgs = pkgs;
          modules = [
            (sources.catppuccin + "/modules/nixos")
            ./system/users/eksno
            ./system/hosts/verse
          ];
        };
      };
    };
}
