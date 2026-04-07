{
  description = "Chronoverse Flake Config";

  inputs = {
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    phonetic.url = "github:startino/phonetic";
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
        overlays = [
          # Hyprland >=0.46 sends wl_output.done instead of zxdg_output_v1.done,
          # so waybar's handleOutputDone never fires and bars are never created
          # on single-monitor setups. See patches/waybar-xdg-output-done-fallback.patch.
          (final: prev: {
            waybar = prev.waybar.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [
                ./patches/waybar-xdg-output-done-fallback.patch
              ];
            });
          })
        ];
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
        # Jorge Lewis (jorge@lewis)
        lewis = nixpkgs.lib.nixosSystem {
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
            inputs.phonetic.nixosModules.default
            ./system/users/jorge
            ./system/hosts/lewis
          ];
        };

        # Jonas Lindberg (eksno@verse)
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
            inputs.phonetic.nixosModules.default
            ./system/users/eksno
            ./system/hosts/verse
          ];
        };
      };
    };
}
