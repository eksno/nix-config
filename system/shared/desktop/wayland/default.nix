{ config, pkgs, ... }:
{
  imports = [
    ./..
  ];

  environment.sessionVariables = rec {
    MOZ_ENABLE_WAYLAND = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
  };
}
