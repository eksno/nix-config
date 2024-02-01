{ config, pkgs, ... }:
{
    fonts = {
        fontDir.enable = true;
        packages = with pkgs; [
            nerdfonts
            noto-fonts
            noto-fonts-cjk
            noto-fonts-emoji
            liberation_ttf
            fira-code
            fira-code-symbols
            mplus-outline-fonts.githubRelease
            dejavu_fonts
            dina-font
            proggyfonts
        ];
        fontconfig = {
            defaultFonts = {
                serif = [ "Ubuntu" ];
                sansSerif = [ "Ubuntu" ];
                monospace = [ "Ubuntu" ];
            };
        };
    };
}
