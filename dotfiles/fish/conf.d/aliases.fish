# Fish shell aliases
# Author: Jonas Lindberg

if status is-interactive
    # File and directory listing
    if type -q bat
        alias cat 'bat --paging=never --style=plain'
        alias less 'bat --paging=always'
        alias more 'bat --paging=always'
    end
    
    if type -q eza
        alias ls 'eza'
        alias la 'eza -a'
        alias ll 'eza -l'
        alias lla 'eza -la'
        alias tree 'eza --tree'
        alias lt 'eza --tree'
    end
    
    # System monitoring
    if type -q btm
        alias htop 'btm --basic --tree --hide_table_gap --dot_marker --mem_as_value'
        alias top 'btm --basic --tree --hide_table_gap --dot_marker --mem_as_value'
    end
    
    # Network
    if type -q ip
        alias ip 'ip --color --brief'
    end
    
    # Vim/Neovim aliases
    if type -q nvim
        alias vi 'nvim'
        alias vim 'nvim'
        alias vimdiff 'nvim -d'
    end
    
    # Git shortcuts
    if type -q git
        alias g 'git'
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
    alias c 'clear'
    alias r 'reload'
    if type -q fd
        alias find 'fd'
    end
    if type -q rg
        alias grep 'rg'
    end
end 