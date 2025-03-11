
{ system, inputs, config, pkgs, ... }:
{

    imports = [
        ../../shared/desktop/wayland/hyprland
        ./locale.nix
    ];

    users.users.eksno = {
        isNormalUser = true;
        description = "Jonas Lindberg";
        extraGroups = [ "networkmanager" "wheel" "docker" ];
    };

    services.xserver.xkb.layout = "us";
    console.useXkbConfig = true;


    services.displayManager.sddm.settings.Autologin.User = "eksno";
    services.openssh.enable = true;

    virtualisation.docker.enable = true;

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [

    ];

    networking.networkmanager.enable = true;
    networking.enableIPv6 = false;
    boot.kernel.sysctl."net.ipv6.conf.all.disable_ipv6" = true;
    boot.kernel.sysctl."net.ipv6.conf.default.disable_ipv6" = true;

    environment.systemPackages = with pkgs; [
        inputs.zen-browser.packages."${system}".default
        lm_sensors
        docker-compose
        steam
        v4l-utils
        beeper
        whisper-ctranslate2
        tmux
        code-cursor
        vivaldi
    ];

    # better way of handling wifi connections
    networking.wireless.iwd = {
        enable = true;
        settings = {
            IPv6 = {
                Enabled = true;
            };
            Settings = {
                AutoConnect = true;
            };
        };
    };
    networking.networkmanager.wifi.backend = "iwd";
    services.connman.wifi.backend = "iwd";
    services.gnome3.gnome-keyring.enable = true;

    boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    boot.kernelModules = [ "v4l2loopback" ];
    boot.initrd.kernelModules = [ "usbhid" "joydev" "xpad" ];
    boot.extraModprobeConfig = '' options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1 bluetooth disable_ertm=1 '';
    security.polkit.enable = true;
}
