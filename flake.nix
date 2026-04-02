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
          # claude-code 2.1.88 was yanked from npm; override to 2.1.87
          (final: prev: {
            claude-code = prev.claude-code.overrideAttrs (old: {
              version = "2.1.87";
              src = prev.fetchzip {
                url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.1.87.tgz";
                hash = "sha256-jorpY6ao1YgkoTgIk1Ae2BQCbqOuEtwzoIG36BP5nG4=";
              };
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
