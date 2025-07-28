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
    glibc
    stdenv.cc.cc.lib # More standard libs

    # Tools that might be needed by build processes of some Python packages (e.g., torch)
    cmake
    pkg-config
    openssl # Often a dependency for various compiled components
    zlib # Often a dependency for various compiled components
  ];

  environment.variables = {
    PUPPETEER_SKIP_DOWNLOAD = "true";
    LD_LIBRARY_PATH = lib.mkForce (
      lib.makeLibraryPath [
        pkgs.stdenv.cc.cc.lib
        pkgs.glibc
        pkgs.glib
      ]
      + ":"
      + "/run/current-system/sw/lib"
    ); # Explicitly add system-wide lib paths

    PKG_CONFIG_PATH = lib.mkForce (
      lib.makeSearchPathOutput "dev" "lib/pkgconfig" [
        pkgs.openssl
        pkgs.zlib
      ]
      + ":"
      + "/run/current-system/sw/lib/pkgconfig"
    ); # Explicitly add system-wide pkgconfig paths

    NIX_LD_LIBRARY_PATH = lib.mkForce (
      lib.makeLibraryPath [
        pkgs.stdenv.cc.cc.lib # provides libstdc++.so.6
        pkgs.glibc # provides glibc
        pkgs.glib
        pkgs.zlib # Common dependency
        # If you uncommented pkgs.cudatoolkit.lib in your shell.nix, you must uncomment it here too
        pkgs.cudatoolkit.lib
      ]
    );
  };

  # To allow unfree packages globally for the system (if you're using CUDA)
  nixpkgs.config.allowUnfree = true;
}
