{ config, pkgs, ... }:

{
  imports = [  # Do not import from ../../shared here. This is just hardware/device related.
    ./hardware-configuration.nix  # Include the results of the hardware scan.
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "tetomini"; # Define your hostname.
 } 
