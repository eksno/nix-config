{ config, lib, pkgs, ... }:

{
  xdg = {
    enable = true;
    userDirs.enable = true;
    userDirs.createDirectories = true;
  }
}
