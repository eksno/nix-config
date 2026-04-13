function cw --description "Claude workstream - spawn a named Claude session in a new vertical tmux pane"
    # Usage:
    #   cw                     → new pane with plain claude
    #   cw fix-ui-bug          → new pane, claude with worktree named fix-ui-bug
    #   cw -r "keyword"        → new pane, resume a session matching keyword
    #   cw -d ~/gtmbud         → new pane in specific directory
    #   cw -d ~/gtmbud api-fix → new pane in gtmbud with worktree named api-fix

    set -l dir ""
    set -l args

    # Parse our flags
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case -d --dir
                set i (math $i + 1)
                set dir $argv[$i]
            case '*'
                set -a args $argv[$i]
        end
        set i (math $i + 1)
    end

    # Build the claude command (always skip permissions)
    set -l flag "--dangerously-skip-permissions"
    set -l cmd "claude $flag"

    # If first arg is -r, pass through for resume
    if test (count $args) -ge 1; and test "$args[1]" = "-r"
        set cmd "claude $flag $args"
    else if test (count $args) -ge 1
        # Treat first arg as worktree name
        set cmd "claude $flag -w $args[1]"
    end

    # Determine target directory
    if test -z "$dir"
        set dir (tmux display-message -p '#{pane_current_path}')
    end

    # Spawn vertical pane and run claude
    tmux split-window -h -c "$dir" "$cmd"
end
