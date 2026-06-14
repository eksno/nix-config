{
  description = "Chronoverse Flake Config";

  inputs = {
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    phonetic.url = "github:startino/phonetic";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Pinned to nixos-25.05 (last release shipping GNOME 48). Used solely
    # to source `gnome-shell` for the breezy-sideview wrapper — GNOME 49
    # removed `--nested` from gnome-shell, breaking the nested-on-Hyprland
    # flow. Re-evaluate this pin once upstream breezy-desktop ships a
    # v49-compatible launch path.
    nixpkgs-gnome48.url = "github:nixos/nixpkgs/nixos-25.05";
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
          permittedInsecurePackages = [ "electron-39.8.10" ];
          packageOverrides = pkgs: {
            intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
          };
        };
        overlays = [ ];
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
