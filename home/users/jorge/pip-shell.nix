{ pkgs ? import <nixpkgs> {} }:
let
  my-python-packages = ps: with ps; [

  ];
  my-python = pkgs.python311.withPackages my-python-packages;
in my-python.env

