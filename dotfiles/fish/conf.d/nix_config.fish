# NixOS specific configuration
# Author: Jonas Lindberg

# Auto-start tmux when opening a new shell
if status is-interactive; and not set -q TMUX
    if type -q tmux
        tmux attach -t $USER || tmux new -s $USER
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
    echo "source $HOME/.nix-profile/share/nix-direnv/direnvrc" > $DIRENV_CONFIG
end

# Enable Nix flakes if nix command exists
if type -q nix
    set -gx NIX_CONFIG "experimental-features = nix-command flakes"
end 