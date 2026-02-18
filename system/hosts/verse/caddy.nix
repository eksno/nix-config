{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.caddy ];

  services.caddy = {
    enable = true;
    virtualHosts."local.echoai.zone" = {
      extraConfig = ''
        tls internal
        reverse_proxy [::1]:5173
      '';
    };
  };
}
