{ config, pkgs, ... }:
{
  imports = [
    # Do not import from ../../lib here. This is just hardware/device related.
    ./hardware-configuration.nix # Include the results of the hardware scan.
    ./boot.nix
    ./networking.nix
    ./bluetooth.nix

    ../../lib/device/intel
  ];

  services.xserver.exportConfiguration = true;

  networking.hostName = "verse"; # Define your hostname.
}
