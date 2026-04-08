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

  # Clear volatile power-mode state on boot so the watchdog re-applies the
  # user's level instead of trusting stale files from the previous session
  systemd.tmpfiles.rules = [
    "D /tmp/power-mode 1777 root root -"
  ];

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

  # Enable Intel workload type hints for firmware power optimization
  systemd.services.intel-workload-hints = {
    description = "Enable Intel workload type hints";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 1 > /sys/devices/pci0000:00/0000:00:04.0/workload_hint/workload_hint_enable 2>/dev/null || true'";
      RemainAfterExit = true;
    };
  };

  # Disable Thunderbolt/TCSS wakeup sources that block S0ix deep sleep
  systemd.services.disable-tb-wakeup = {
    description = "Disable Thunderbolt wakeup sources for deeper sleep";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'for src in TXHC TDM0 TRP0 TRP1; do echo $src > /proc/acpi/wakeup 2>/dev/null || true; done'";
      RemainAfterExit = true;
    };
  };

  networking.hostName = "verse"; # Define your hostname.
}
