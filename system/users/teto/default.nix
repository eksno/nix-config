
{ config, pkgs, ... }:
{
    imports = [
        ../../lib/desktop/wayland/hyprland
        ./locale.nix
    ];

    dotfiles.username = "teto";

    programs = {
        steam = {
            enable = true;
        };
    };
    programs.steam.gamescopeSession.enable = true;



  users.users.teto = {
    isNormalUser = true;
    description = "Teto";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
  };

    services.displayManager.sddm.settings = {
        Autologin = {
            User = "teto";
        };
    };


    #services.xserver = {
        #layout = "no";   
        #xkbVariant = "nodeadkeys";  
    # };

  services.udev.extraRules = '' SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu" '';
  environment.systemPackages = with pkgs; [
    # docker-compose
    wally-cli
    icomoon-feather
  ];

}
