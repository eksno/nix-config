{ config, pkgs, ... }:
{
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    6443
    5900
  ];
  # Enable networking
  networking.networkmanager.enable = true;
}
