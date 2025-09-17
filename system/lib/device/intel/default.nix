{ config, pkgs, ... }:
{
  hardware.enableRedistributableFirmware = true;
  services.xserver.videoDrivers = [ "intel" ];
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "bbswitch"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [
    "i915.enable_guc=3"
    "i915.enable_psr=2"
    "i915.enable_fbc=1"
    "i915.enable_dc=2"
  ];
  powerManagement.powertop.enable = true;
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
      vpl-gpu-rt
    ];
  };
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  }; # Force intel-media-driver
}
