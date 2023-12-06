
{ config, pkgs, ... }:
{
  imports = [
    ../fish.nix
    ../fonts.nix
    ../locale.nix
    ../networking.nix
    ../system.nix
  ];

  # Enable Flakes and the new command-line tool
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  environment.systemPackages = with pkgs; [
    git # Flakes use Git to pull dependencies from data sources, so Git must be installed first
    gccgo
    libgcc
    neovim
    wget
    curl
  ];

  # Set default editor to neovim
  environment.variables.EDITOR = "neovim";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Support ntfs
  boot.supportedFilesystems = [ "ntfs" ];
}
