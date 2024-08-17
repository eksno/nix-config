{ config, lib, pkgs, ... }:

{
    programs.librewolf = {
        enable = true;

        # Enable WebGL, Firefox Sync, cookies and history
        settings = {
            "webgl.disabled" = false;
            "privacy.resistFingerprinting" = false;
            "privacy.clearOnShutdown.downloads" = false;
            "privacy.clearOnShutdown.history" = false;
            "privacy.clearOnShutdown.cookies" = false;
            "network.cookie.lifetimePolicy" = 0;
            "identity.fxaccounts.enabled" = true;
        };
    };
}
