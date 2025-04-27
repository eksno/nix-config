# Main fish configuration file
# Author: Jonas Lindberg

# Path configuration
fish_add_path ~/.local/bin
fish_add_path ~/.cargo/bin
fish_add_path ~/.npm/bin

# Set editor
set -gx EDITOR nvim
set -gx VISUAL nvim

# Source all files from conf.d directory
for file in ~/.config/fish/conf.d/*.fish
    source $file
end

# Set GPG TTY for proper GPG agent operation
if status is-interactive
    set -gx GPG_TTY (tty)
    if type -q gpg-connect-agent
        gpg-connect-agent updatestartuptty /bye >/dev/null
    end
end

# Set up autojump if available
if test -e /usr/share/autojump/autojump.fish
    source /usr/share/autojump/autojump.fish
else if test -e /run/current-system/sw/share/autojump/autojump.fish
    source /run/current-system/sw/share/autojump/autojump.fish
end

# Set terminal colors
if test -e ~/.dir_colors
    if type -q dircolors
        eval (dircolors -c ~/.dir_colors)
    end
end

# Custom user functions
function reload
    source ~/.config/fish/config.fish
    echo "Fish config reloaded!"
end

# NixOS specific settings
if test -e /etc/NIXOS
    # Add any NixOS-specific settings here
    set -gx NIX_PATH $HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels
end
