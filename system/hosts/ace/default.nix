{ config, pkgs, ... }:
{
  imports = [
    # Do not import from ../../lib here. This is just hardware/device related.
    ./hardware-configuration.nix # Include the results of the hardware scan.
    ../../lib/device/nvidia
  ];
  services.xserver.exportConfiguration = true;

  systemd.extraConfig = ''
    DefaultTimeoutStopSec=10s
  '';

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "ace"; # Define your hostname.
}
