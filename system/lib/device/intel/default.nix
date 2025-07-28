{ config, pkgs, ... }:
{
    imports = [
        ./..
    ];
    hardware.enableRedistributableFirmware = true; 
    services.xserver.videoDrivers = [ "modesetting" ];
    boot.blacklistedKernelModules = [ "nouveau" "nvidia" "bbswitch" ];
    boot.kernelParams = [ "i915.force_probe=7d55" ];  
    boot.kernelModules = [ "kvm-intel" ];

    hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
            intel-media-driver # LIBVA_DRIVER_NAME=iHD
            intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
            libvdpau-va-gl
        ];
    };
    environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; }; # Force intel-media-driver
}
