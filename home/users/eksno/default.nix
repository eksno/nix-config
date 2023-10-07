{ config, lib, pkgs, ... }:

{
  imports = [
    ../../shared
  ];

  programs.git.userName = "Jonas Lindberg";
  programs.git.userEmail = "eksno@protonmail.com";
}