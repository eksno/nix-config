{ config, lib, pkgs, ... }:

{
  imports = [
    ../homemanager.nix

    ./gpgagent.nix
    ./tmux.nix
    ./xdg.nix

    ./programs.nix
  ];
}
