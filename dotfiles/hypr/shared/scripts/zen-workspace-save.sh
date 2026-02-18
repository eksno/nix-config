#!/usr/bin/env bash
SAVE_FILE="$HOME/.local/share/zen-browser-workspace/workspaces"
mkdir -p "$(dirname "$SAVE_FILE")"

while true; do
    workspaces=$(hyprctl clients -j | jq -r '.[] | select(.class == "zen-beta") | .workspace.id')
    if [[ -n "$workspaces" ]]; then
        echo "$workspaces" > "$SAVE_FILE.tmp" && mv "$SAVE_FILE.tmp" "$SAVE_FILE"
    fi
    sleep 30
done
