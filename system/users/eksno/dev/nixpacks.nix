{ pkgs, ... }:
{
    environment.systemPackages = with pkgs; [
        nixpacks
    ];
}
