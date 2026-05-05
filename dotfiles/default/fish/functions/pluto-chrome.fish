function pluto-chrome --description "Launch Chrome with CDP on 9222 and SSH reverse tunnel to pluto"
    set -l profile_dir "$HOME/.config/chrome-data"
    set -l cdp_port 9222

    if pgrep -af "user-data-dir=$profile_dir" >/dev/null 2>&1
        echo "Chrome (chrome-data) already running"
    else
        if not test -d "$profile_dir"
            echo "ERROR: $profile_dir does not exist"
            return 1
        end
        echo "Launching Chrome on chrome-data with CDP on $cdp_port..."
        nohup google-chrome \
            --remote-debugging-port=$cdp_port \
            --user-data-dir="$profile_dir" \
            --profile-directory=Default \
            >/tmp/chrome-cdp.log 2>&1 &
        disown
    end

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
