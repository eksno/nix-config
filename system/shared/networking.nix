{ config, pkgs, ... }:
{
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    6443
    5900
    5173
    5174
    5175
    5176
    5177
    5178
    5179
    5180
  ];
  # Enable networking
  networking.networkmanager.enable = true;
}
