{ config, pkgs, ... }:
{
    imports = [
        ./..
    ];
    hardware.enableRedistributableFirmware = true; 
    services.xserver.videoDrivers = [ "intel" "modesetting" ];
    boot.blacklistedKernelModules = [ "nouveau" "nvidia" "bbswitch" ];
    boot.kernelParams = [ "i915.force_probe=7d55" ];  
    boot.kernelModules = [ "kvm-intel" ];

    # Accelerated Video Playback (https://nixos.wiki/wiki/Accelerated_Video_Playback)
    nixpkgs.config.packageOverrides = pkgs: {
        intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
    };
    hardware.opengl = {
        enable = true;
        driSupport = true;
        extraPackages = with pkgs; [
            intel-media-driver # LIBVA_DRIVER_NAME=iHD
            intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
            libvdpau-va-gl
        ];
    };
    environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; }; # Force intel-media-driver
}
