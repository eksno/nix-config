# NixOS specific configuration
# Author: Jonas Lindberg

# Auto-start tmux when opening a new shell, but only if the terminal is Kitty
if status is-interactive; and not set -q TMUX; and set -q KITTY_WINDOW_ID
    if type -q tmux
        if tmux has-session 2>/dev/null
            # Server already running — add a window and attach
            if tmux has-session -t $USER 2>/dev/null
                tmux new-window -t $USER -c "$PWD"
            end
            tmux attach -t $USER
        else
            # Server not running — start detached, restore sessions, then attach
            tmux new-session -d -s $USER -c "$PWD"
            if test -e ~/.local/share/tmux/resurrect/last
                # Set TMUX so restore.sh connects to the right server socket
                TMUX=(tmux display-message -p '#{socket_path},#{pid},0') \
                    ~/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh 2>/dev/null
            end
            tmux attach -t $USER
        end
    end
end

# Set up direnv hook for fish
if type -q direnv
    direnv hook fish | source
end

# Configure eza with icons if available
if type -q eza
    set -gx EZA_ICONS_AUTO 1
end

# Set up nix-direnv if available
if test -e $HOME/.nix-profile/share/nix-direnv/direnvrc
    set -gx DIRENV_CONFIG $HOME/.config/direnv/direnvrc
    echo "source $HOME/.nix-profile/share/nix-direnv/direnvrc" >$DIRENV_CONFIG
end

# Enable Nix flakes if nix command exists
if type -q nix
    set -gx NIX_CONFIG "experimental-features = nix-command flakes"
end
