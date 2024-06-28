{ config, pkgs, ... }:
{
    users.defaultUserShell = pkgs.fish;
    environment.shells = with pkgs; [ fish ];

    programs = {
        fish = {
            enable = true;
            interactiveShellInit = "tmux attach -t $USER || tmux new -s $USER";
        };
        bash = {
            interactiveShellInit = ''
                if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
                then
                shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
                exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
                fi
            '';
        };
    }
}
