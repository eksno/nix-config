# Environment variables
# Author: Jonas Lindberg

# XDG Base Directories
set -gx XDG_CONFIG_HOME $HOME/.config
set -gx XDG_DATA_HOME $HOME/.local/share
set -gx XDG_CACHE_HOME $HOME/.cache
set -gx XDG_STATE_HOME $HOME/.local/state

# Set language
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8

# Set editor
set -gx EDITOR nvim
set -gx VISUAL nvim

# Set browser
if type -q firefox
    set -gx BROWSER firefox
else if type -q google-chrome
    set -gx BROWSER google-chrome
else if type -q chromium
    set -gx BROWSER chromium
end

# Set man pager
if type -q bat
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
    set -gx MANROFFOPT "-c"
end

# Rust environment
if test -d $HOME/.cargo
    set -gx CARGO_HOME $HOME/.cargo
    fish_add_path $CARGO_HOME/bin
end

# Node.js environment
if test -d $HOME/.npm
    set -gx NPM_CONFIG_PREFIX $HOME/.npm
    fish_add_path $NPM_CONFIG_PREFIX/bin
end

# Go environment
if test -d $HOME/go
    set -gx GOPATH $HOME/go
    fish_add_path $GOPATH/bin
end

# Python environment
if test -d $HOME/.local/bin
    fish_add_path $HOME/.local/bin
end