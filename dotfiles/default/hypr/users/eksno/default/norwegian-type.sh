#!/usr/bin/env bash
# Type a Norwegian letter into the focused window.
#
# wtype works in native Wayland surfaces (Zen/Firefox, GTK, Qt, terminals)
# but Electron/Chromium drops virtual_keyboard_unstable_v1 events, so for
# those we shove the char on the clipboard and simulate Ctrl+V through
# ydotool's uinput backend instead. Old clipboard contents are restored.
set -eu

char="$1"
class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' | tr '[:upper:]' '[:lower:]')

case "$class" in
    discord|beeper|slack|spotify|code|*chrome*|*chromium*|*electron*)
        old=$(wl-paste --no-newline 2>/dev/null || true)
        printf %s "$char" | wl-copy
        # Release any modifiers the user is still physically holding before
        # firing Ctrl+V — otherwise a held ALT turns the paste into Ctrl+Alt+V
        # in Discord (no-op). 42/54 = L/R Shift, 56/100 = L/R Alt.
        ydotool key 42:0 54:0 56:0 100:0 29:1 47:1 47:0 29:0
        (sleep 0.2; printf %s "$old" | wl-copy) >/dev/null 2>&1 &
        ;;
    *)
        wtype -- "$char"
        ;;
esac
