#!/usr/bin/env bash
# Restore mosh connections from tmux-resurrect save data.
# Called without args by resurrect's inline strategy mapping.
# Reads the save file to find the mosh-client -# hostname for the current pane.
save_file="$(readlink -f ~/.local/share/tmux/resurrect/last)"
[ -f "$save_file" ] || exit 1

pane_id="$(tmux display-message -p $'#{session_name}\t#{window_index}\t#{pane_index}')"
session="${pane_id%%	*}"
rest="${pane_id#*	}"
window="${rest%%	*}"
pane="${rest#*	}"

host=$(awk -F'\t' -v s="$session" -v w="$window" -v p="$pane" \
    '$1=="pane" && $2==s && $3==w && $6==p { match($11, /-# ([^ |]+)/, m); print m[1] }' \
    "$save_file")

[ -n "$host" ] && exec mosh "$host"
