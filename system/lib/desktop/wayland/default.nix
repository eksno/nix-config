{ config, pkgs, ... }:
{
  imports = [
    ./..
  ];

  services.xserver.enable = true;

  environment.sessionVariables = rec {
    MOZ_ENABLE_WAYLAND = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    wl-screenrec
  ];
}
