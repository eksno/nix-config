{ config, pkgs, ... }:
{
    fonts.fontDir.enable = true;
    fonts.packages = with pkgs; [
        nerd-fonts.fira-code
        noto-fonts
        noto-fonts-cjk-sans
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
