{ pkgs ? import <nixpkgs> {} }:
let
  my-python-packages = ps: with ps; [
    pandas
    requests
    numpy pillow toolz black markdown matplotlib
  ];
  my-python = pkgs.python3.withPackages my-python-packages;
in my-python.env
