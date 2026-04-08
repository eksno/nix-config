{ config, pkgs, ... }:
{
  hardware.enableRedistributableFirmware = true;
  services.xserver.videoDrivers = [ "intel" ];
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "bbswitch"
    "xe"          # Prevent dual GPU driver loading (i915 is primary)
  ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [
    "i915.enable_guc=3"
    "i915.enable_psr=2"
    "i915.enable_fbc=1"           # Frame buffer compression
    "i915.enable_dc=4"            # Deeper display power states
    "pcie_aspm=force"             # Force ASPM even if BIOS didn't enable
    "nmi_watchdog=0"              # Disable NMI watchdog (~0.5W)
    "snd_hda_intel.power_save=1"  # Audio codec power save
    "iwlwifi.power_save=1"        # WiFi power save
    "acpi.ec_no_wakeup=1"         # Prevent EC spurious wakes during s2idle
    "usbcore.autosuspend=1"       # USB autosuspend after 1s (default 2s)
  ];

  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=1
    options iwlwifi power_save=1 power_level=5
  '';

  # Intel thermal management — reads DPTF tables from BIOS for adaptive tuning
  services.thermald.enable = true;

  # Reduce NVMe/storage wake-ups for power savings
  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = 6000; # 60s instead of 15s
    "vm.laptop_mode" = 5;                  # Delay disk writes
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      # intel-vaapi-driver
      # libvdpau-va-gl
      vpl-gpu-rt
      intel-compute-runtime # OpenCL for Intel Arc / Iris Xe
      level-zero # Intel Level Zero
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  }; # Force intel-media-driver
}
