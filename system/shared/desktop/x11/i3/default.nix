{ config, pkgs, ... }:
{
  imports = [
    ./..
  ];

  services.xserver = {
    enable = true;
    windowManager.i3.enable = true;
  };
}
