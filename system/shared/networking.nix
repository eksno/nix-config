{ config, pkgs, ... }:
{
  # Open ports in the firewall.
  networking.firewall.allowedUDPPorts = [
    21000
    21001
    21002
    21003
    21004
    21005
    21006
    21007
    21008
    21009
    21010
  ];

  networking.firewall.allowedTCPPorts = [
    21000
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
