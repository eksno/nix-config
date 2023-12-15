{ pkgs ? import <nixpkgs> {} }:
let
  my-python-packages = ps: with ps; [

  ];
  my-python = pkgs.python311.withPackages my-python-packages;

in pkgs.mkShell rec {
  name = "impurePythonEnv";
  venvDir = "./.venv";
  buildInputs = [
    my-python
    # A Python interpreter including the 'venv' module is required to bootstrap
    # the environment.
    # pythonPackages.python

    # This executes some shell code to initialize a venv in $venvDir before
    # dropping into the shell
    # pythonPackages.venvShellHook

    # Those are dependencies that we would like to use from nixpkgs, which will
    # add them to PYTHONPATH and thus make them accessible from within the venv.
    # pythonPackages.numpy
    # pythonPackages.requests

    # In this particular example, in order to compile any binary extensions they may
    # require, the Python modules listed in the hypothetical requirements.txt need
    # the following packages to be installed locally:
    pkgs.libxml2
    pkgs.libxslt
    pkgs.libzip
    pkgs.zlib
  ];
  shellHook = ''
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib.outPath}/lib:$LD_LIBRARY_PATH"
    '';


}
