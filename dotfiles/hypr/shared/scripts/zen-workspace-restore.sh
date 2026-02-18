#!/usr/bin/env bash
SAVE_FILE="$HOME/.local/share/zen-browser-workspace/workspaces"
[[ -f "$SAVE_FILE" ]] || exit 0

mapfile -t saved < "$SAVE_FILE"
total=${#saved[@]}
[[ $total -gt 0 ]] || exit 0

socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
count=0

while read -r line; do
    if [[ "$line" == openwindow\>\>* ]]; then
        data="${line#openwindow>>}"
        addr="${data%%,*}"
        rest="${data#*,}"
        rest="${rest#*,}"
        class="${rest%%,*}"

        if [[ "$class" == "zen-beta" && $count -lt $total ]]; then
            sleep 0.1
            hyprctl dispatch movetoworkspacesilent "${saved[$count]},address:0x$addr"
            ((count++))
            [[ $count -ge $total ]] && exit 0
        fi
    fi
done < <(socat -u UNIX-CONNECT:"$socket" -)
