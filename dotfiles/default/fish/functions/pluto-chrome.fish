function pluto-chrome --description "Launch Chrome with CDP on 9222 and SSH reverse tunnel to pluto (kills any prior instances first)"
    set -l profile_dir "$HOME/.config/chrome-data"
    set -l cdp_port 9222

    if not test -d "$profile_dir"
        echo "ERROR: $profile_dir does not exist"
        return 1
    end

    set -l chrome_pids (pgrep -f "user-data-dir=$profile_dir" 2>/dev/null)
    set -l ssh_pids (pgrep -f '^ssh .*-N.* pluto$' 2>/dev/null)

    if test -n "$chrome_pids$ssh_pids"
        echo "Killing prior instances..."
        if test -n "$chrome_pids"
            kill $chrome_pids 2>/dev/null
        end
        if test -n "$ssh_pids"
            kill $ssh_pids 2>/dev/null
        end
        for i in (seq 1 10)
            set chrome_pids (pgrep -f "user-data-dir=$profile_dir" 2>/dev/null)
            set ssh_pids (pgrep -f '^ssh .*-N.* pluto$' 2>/dev/null)
            test -z "$chrome_pids$ssh_pids"; and break
            sleep 0.3
        end
        set chrome_pids (pgrep -f "user-data-dir=$profile_dir" 2>/dev/null)
        set ssh_pids (pgrep -f '^ssh .*-N.* pluto$' 2>/dev/null)
        if test -n "$chrome_pids$ssh_pids"
            echo "Force-killing stragglers: chrome=$chrome_pids ssh=$ssh_pids"
            test -n "$chrome_pids"; and kill -9 $chrome_pids 2>/dev/null
            test -n "$ssh_pids"; and kill -9 $ssh_pids 2>/dev/null
            sleep 0.5
        end
    end

    echo "Launching Chrome on chrome-data with CDP on $cdp_port..."
    nohup google-chrome \
        --remote-debugging-port=$cdp_port \
        --user-data-dir="$profile_dir" \
        --profile-directory=Default \
        >/tmp/chrome-cdp.log 2>&1 &
    disown

    for i in (seq 1 20)
        if curl -sf "http://localhost:$cdp_port/json/version" >/dev/null 2>&1
            break
        end
        sleep 0.5
    end

    if not curl -sf "http://localhost:$cdp_port/json/version" >/dev/null 2>&1
        echo "ERROR: Chrome CDP not responding on $cdp_port (see /tmp/chrome-cdp.log)"
        return 1
    end
    echo "Chrome CDP up on localhost:$cdp_port"

    echo "Starting SSH reverse tunnel to pluto (Ctrl-C stops the tunnel; Chrome keeps running)"
    ssh -v -N pluto
end
