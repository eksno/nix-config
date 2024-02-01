{ config, pkgs, ... }:
{
  imports = [
    ../wayland/hyprland
    ../bluetooth.nix
    ../fish.nix
    ../fonts.nix
    ../locale.nix
    ../networking.nix
    ../system.nix
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
  ];

  services.xserver = {
    enable = true;
    # sddm config
    displayManager.sddm = {
      enable = true;
      
      settings = {
        Autologin = {
            Session = "hyprland";
        };
      };

      enableHidpi = true;
      theme = "sugar-dark";
      wayland = {
        enable = true;
      };
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Enable Flakes and the new command-line tool
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  environment.systemPackages = with pkgs; [
    git # Flakes use Git to pull dependencies from data sources, so Git must be installed first
    gccgo
    libgcc
    neovim
    wget
    curl
  ];

  # Set default editor to neovim
  environment.variables.EDITOR = "neovim";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Support ntfs
  boot.supportedFilesystems = [ "ntfs" ];

  environment.sessionVariables = rec {
    MOZ_ENABLE_WAYLAND = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
  };

  hardware = {
    opengl.enable = true;
  };

  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
      ];
    };
  };
}
