{ config, pkgs, ... }:
{
    fonts.fontDir.enable = true;
    fonts.packages = with pkgs; [
        (nerdfonts.override { fonts = [ "FiraCode" ]; })
        noto-fonts
        noto-fonts-cjk
        noto-fonts-emoji
        liberation_ttf
        fira-code
        fira-code-symbols
        mplus-outline-fonts.githubRelease
        dina-font
        proggyfonts
    ];
    fonts.fontconfig = {
        defaultFonts = {
            serif = [  "Liberation Serif" "Vazirmatn" ];
            sansSerif = [ "Ubuntu" "Vazirmatn" ];
            monospace = [ "Ubuntu Mono" ];
        };
    };
}
