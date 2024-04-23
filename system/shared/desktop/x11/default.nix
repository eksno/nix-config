{ config, pkgs, ... }:
{
    imports = [
        ./..
    ];

    environment.pathsToLink = [ "/libexec" ]; # links /libexec from derivations to /run/current-system/sw 
}
