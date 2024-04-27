
{ config, pkgs, ... }:
{
    imports = [
        ../../shared/headless
        ./locale.nix
    ];

    users.users.teto = {
        isNormalUser = true;
        description = "teto";
        extraGroups = [ "networkmanager" "wheel" "video" ];
    };


    services.openssh = {
        enable = true;
    };
    

    environment.systemPackages = with pkgs; [

    ];

}
