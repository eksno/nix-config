
{ config, lib, pkgs, ... }:

{
  home.file.".config/hypr" = {
    source = ./config;
    recursive = true;   # link recursively
  };
}
