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
  # Meteor Lake audio: snd_hda_intel sometimes wins the module-load race over
  # the SOF DSP driver and strands the controller (no sound card, PipeWire
  # falls back to "Dummy Output"). Force-load the SOF MTL driver so it always
  # claims 0000:00:1f.3.
  boot.kernelModules = [ "snd_sof_pci_intel_mtl" ];
}
