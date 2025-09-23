{
  config,
  pkgs,
  lib,
  ...
}:

{
  # This makes NixOS's /run/wrappers/bin available in PATH,
  # and ensures executables use nix-ld if needed.
  programs.nix-ld.enable = true;

  # Some programs might also need dynamic libraries wrapped.
  # This option takes a list of packages whose libraries should be exposed
  # to the dynamic linker via /run/opengl-driver/lib and similar paths.
  # Add the relevant packages here:
  # programs.nix-ld.extraLibraries = with pkgs; [
  #   stdenv.cc.cc.lib # for libstdc++.so.6
  #   glibc
  #   zlib
  #   cudatoolkit.lib
  # ];
  environment.systemPackages = with pkgs; [
    python312
    python312Packages.pip
    python312Packages.black
    python312Packages.isort
    python312Packages.autoflake
    python312Packages.flake8
    uv

    # Core system libraries for C++ applications
    gcc-unwrapped # Provides libstdc++
    gcc
    glibc
    stdenv.cc.cc.lib # More standard libs

    # Tools that might be needed by build processes of some Python packages (e.g., torch)
    cmake
    pkg-config
    openssl # Often a dependency for various compiled components
    zlib # Often a dependency for various compiled components
  ];

  # Static base LD_LIBRARY_PATH (for non-interactive/login sessions; resolves conflicts)
  # Use mkForce to override other modules like python.nix or shells-environment.nix
  environment.variables.LD_LIBRARY_PATH = lib.mkForce "${pkgs.stdenv.cc.cc.lib}/lib";

  # Dynamic prepend for bash/zsh interactive shells
  environment.interactiveShellInit = ''
    # Prepend GCC lib to LD_LIBRARY_PATH if non-empty (POSIX sh syntax for broad compatibility)
    if [ -n "$LD_LIBRARY_PATH" ]; then
      export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib":$LD_LIBRARY_PATH
    else
      export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib"
    fi
  '';

  # For fish: Generate a system-wide config snippet with fish-specific dynamic prepend
  # This creates /etc/fish/config.fish.d/00-nixos-ld-library-path.fish (sourced by fish on startup)
  environment.etc."fish/config.fish.d/00-nixos-ld-library-path.fish".text = ''
    # Prepend GCC lib to LD_LIBRARY_PATH if set (fish syntax)
    if set -q LD_LIBRARY_PATH
      set -gx LD_LIBRARY_PATH ${pkgs.stdenv.cc.cc.lib}/lib $LD_LIBRARY_PATH
    else
      set -gx LD_LIBRARY_PATH ${pkgs.stdenv.cc.cc.lib}/lib
    end
  '';
}
