{ config, pkgs, ... }:
{
    users.defaultUserShell = pkgs.fish;
    environment.shells = with pkgs; [ fish ];
    programs = {
        fish = {
            enable = true;
            interactiveShellInit = "tmux attach -t $USER || tmux new -s $USER";
        };
    };
}
