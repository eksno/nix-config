{ config, lib, pkgs, ... }:

{
  imports = [
    ../homemanager.nix

    ./gpgagent.nix
    ./xdg.nix

    ./programs.nix
  ];
}
