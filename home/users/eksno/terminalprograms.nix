{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    sqlcmd
    pkgs.nodePackages.vercel
    pkgs.nodePackages.postcss
  ];
}
