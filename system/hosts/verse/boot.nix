{ pkgs,  ... }:

{
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    boot.kernelModules = [ "v4l2loopback" ];
    boot.initrd.kernelModules = [ "usbhid" "joydev" "xpad" ];
    boot.extraModprobeConfig = '' options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1 bluetooth disable_ertm=1 '';
}
