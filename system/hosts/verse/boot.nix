{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.initrd.kernelModules = [
    "usbhid"
    "joydev"
    "xpad"
  ];
}
