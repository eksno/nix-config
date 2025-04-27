# Custom fish prompt
# Author: Jonas Lindberg

function fish_prompt --description 'Write out the prompt'
    set -l last_status $status

    # User
    set_color brblue
    echo -n $USER
    set_color normal
    echo -n '@'

    # Host
    set_color brgreen
    echo -n (prompt_hostname)
    set_color normal
    echo -n ':'

    # PWD
    set_color $fish_color_cwd
    echo -n (prompt_pwd)
    set_color normal

    # Git status
    set -l git_info
    if command -sq git
        set -l git_branch (git branch 2>/dev/null | sed -n '/\* /s///p')
        if test -n "$git_branch"
            set -l git_status (git status --porcelain 2>/dev/null)
            set_color yellow
            echo -n " ($git_branch"
            
            if test -n "$git_status"
                set_color red
                echo -n "*"
            end
            
            set_color yellow
            echo -n ")"
            set_color normal
        end
    end

    # Status and prompt char
    if test $last_status -eq 0
        set_color green
    else
        set_color red
        echo -n " [$last_status]"
    end

    echo -n " → "
    set_color normal
end 