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

  environment.systemPackages = with pkgs; [
    python312
    python312Packages.pip
    python312Packages.black
    python312Packages.isort
    python312Packages.autoflake
    python312Packages.flake8
    uv

    # Tools that might be needed by build processes of some Python packages (e.g., torch)
    pkg-config
    openssl # Often a dependency for various compiled components
    zlib # Often a dependency for various compiled components
  ];
}
