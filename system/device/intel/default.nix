{ config, pkgs, ... }:
{
    hardware.enableRedistributableFirmware = true; 
    services.xserver.videoDrivers = [ "intel" ];  # modesetting didn't help
    boot.blacklistedKernelModules = [ "nouveau" "nvidia" ];  # bbswitch
    boot.kernelParams = [ "acpi_rev_override=5" "i915.enable_guc=2" "i915.force_probe=7d55" ];  
    boot.kernelModules = [ "kvm-intel" ];
    services.fwupd.enable = true;
    hardware.opengl = {
        enable = true;
        driSupport = true;
        extraPackages = with pkgs; [
            intel-media-driver # LIBVA_DRIVER_NAME=iHD
            vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
            vaapiVdpau
            libvdpau-va-gl
        ];
    };
}
