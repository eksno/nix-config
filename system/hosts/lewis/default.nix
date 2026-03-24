{ config, pkgs, ... }:
{
  imports = [
    # Do not import from ../../lib here. This is just hardware/device related.
    ./hardware-configuration.nix # Include the results of the hardware scan.
    ./boot.nix
    ./networking.nix
    ./bluetooth.nix
    ./caddy.nix
    ../../lib/device/intel
  ];

  services.xserver.exportConfiguration = true;

  # Cap battery charge at 80% to reduce cell voltage stress and slow degradation
  systemd.services.battery-charge-threshold = {
    description = "Set battery charge threshold to 80%";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold'";
      RemainAfterExit = true;
    };
  };

  networking.hostName = "lewis"; # Define your hostname.

  services.openssh = {
    enable = true;
    settings.PubkeyAuthentication = true;
  };
}
