{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.caddy ];

  security.pki.certificateFiles = [
    /etc/nixos/certs/caddy-local-ca.pem
  ];

  services.caddy = {
    enable = true;
    virtualHosts."local.echoai.zone" = {
      extraConfig = ''
        tls internal
        reverse_proxy [::1]:5173
      '';
    };
    virtualHosts."local.openclaw.zone" = {
      extraConfig = ''
        tls internal
        reverse_proxy https://openclaw-custom-production.up.railway.app {
          header_up Host {upstream_hostport}
        }
      '';
    };
  };
}
