{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix  # Include the results of the hardware scan.
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "chrono"; # Define your hostname.
 } 
