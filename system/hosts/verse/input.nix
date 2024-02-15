
{ config, lib, pkgs, ... }:
{
  #services.xserver.displayManager.sessionCommands = "sleep 5 && ${pkgs.xorg.xmodmap}/bin/xmodmap -e 'keysym u = i I i I' &";
}
