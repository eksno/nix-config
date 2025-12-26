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
    python313
    python313Packages.pip
    python313Packages.black
    python313Packages.isort
    python313Packages.autoflake
    python313Packages.flake8
    python313Packages.tkinter
    uv

    # Tools that might be needed by build processes of some Python packages (e.g., torch)
    pkg-config
    openssl # Often a dependency for various compiled components
    zlib # Often a dependency for various compiled components
    tesseract # ocr
  ];
}
