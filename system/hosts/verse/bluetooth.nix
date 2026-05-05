{ config, pkgs, ... }:
{
  # Bluetooth
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
  hardware.bluetooth.settings.General.Experimental = true; # exposes Battery1 D-Bus iface for headphones, AirPods, etc.
  services.blueman.enable = true;
  boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=1
    options btusb enable_autosuspend=0
  '';
}
