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

  # Cap battery charge at 80% to reduce cell voltage stress and slow degradation
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="power_supply", ATTR{charge_control_end_threshold}="80"
  '';

  networking.hostName = "verse"; # Define your hostname.
}
