
{ config, pkgs, ... }:
{
  imports = [
    ../../shared/desktop/wayland/hyprland
  ];

  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };

  services.xserver.displayManager.sddm.settings = {
    Autologin = {
        User = "lucy";
    };
  };

  services.openssh = {
    enable = false;
  };

  services.udev.extraRules = '' SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu" '';
   


  environment.systemPackages = with pkgs; [
    wally-cli
  ];

  hardware.keyboard.zsa = {
    enable = true;
  };
}
