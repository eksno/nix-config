# Fish shell aliases
# Author: Jonas Lindberg

if status is-interactive
    if type -q nix
        alias nd 'nix develop'
        alias ndc 'nix develop ./.nix-develop-cache'
        alias ndcc 'nix develop --profile .nix-develop-cache --command true'
        alias ndcclean 'nix develop --delete-cache ./.nix-develop-cache'
    end

    # File and directory listing
    if type -q bat
        alias cat 'bat --paging=never --style=plain'
        alias less 'bat --paging=always'
        alias more 'bat --paging=always'
    end

    if type -q eza
        alias ls eza
        alias la 'eza -a'
        alias ll 'eza -l'
        alias lla 'eza -la'
        alias tree 'eza --tree'
        alias lt 'eza --tree'
    end

    # System monitoring
    if type -q btop
        alias htop btop
        alias top btop
    end

    # Network
    if type -q ip
        alias ip 'ip --color --brief'
    end

    # Vim/Neovim aliases
    if type -q nvim
        alias vi nvim
        alias vim nvim
        alias vimdiff 'nvim -d'
    end

    # Git shortcuts
    if type -q git
        alias g git
        alias ga 'git add'
        alias gc 'git commit'
        alias gp 'git push'
        alias gs 'git status'
        alias gl 'git log'
    end

    # Directory navigation
    alias .. 'cd ..'
    alias ... 'cd ../..'
    alias .... 'cd ../../..'
    alias ..... 'cd ../../../..'

    # Common utilities
    alias c clear
    alias r reload
    if type -q fd
        alias find fd
    end
    if type -q rg
        alias grep rg
    end
end

