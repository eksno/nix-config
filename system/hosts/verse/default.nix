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

  # Migrate key IRQs to LP E-cores (cpu20-21) so P-cores/E-cores sleep deeper
  systemd.services.irq-lp-cores = {
    description = "Migrate IRQs to LP E-cores for deeper idle";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'for irq in $(${pkgs.gnugrep}/bin/grep -l \"i915\\|iwlwifi\\|nvme\\|AudioDSP\" /proc/irq/*/actions 2>/dev/null | cut -d/ -f4); do echo 20-21 > /proc/irq/$irq/smp_affinity_list 2>/dev/null || true; done'";
      RemainAfterExit = true;
    };
  };

  # Wireplumber: force software volume on the internal speakers so the
  # CS35L41 smart amps always see full-amplitude analog from the codec.
  # Below 100% on the sink would otherwise drive the hardware "Speaker"
  # attenuator down (-18 dB at 50%, -36 dB at 25%), starving the smart
  # amp's DSP tuning and making playback sound thin at low volumes.
  # With soft-mixer enabled the hardware attenuator stays at 0 dB and
  # all volume changes happen in software.
  services.pipewire.wireplumber.extraConfig."51-cs35l41-soft-mixer" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          { "device.name" = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic"; }
        ];
        actions = {
          update-props = {
            "api.alsa.soft-mixer" = true;
          };
        };
      }
    ];
  };

  networking.hostName = "verse"; # Define your hostname.
}
