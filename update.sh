#!/usr/bin/env bash

# Verify not sudo
[[ -z $SUDO_USER ]] && echo "Running" || exit

# ---- Parse args ----
do_nix=false
reconfigure=false
for arg in "$@"; do
    case "$arg" in
        nix) do_nix=true ;;
        reconfigure) reconfigure=true ;;
        *) echo "Unknown arg: $arg" >&2; echo "Usage: $0 [nix] [reconfigure]" >&2; exit 1 ;;
    esac
done

# `reconfigure` alone: prompt for host + rebuild
if $reconfigure && ! $do_nix; then
    do_nix=true
fi

# Bare invocation: nix only
if ! $do_nix; then
    do_nix=true
fi

# Use `sudo -A` when SUDO_ASKPASS is set (lets non-TTY callers like Claude Code
# authenticate via secure-askpass); fall back to plain `sudo` otherwise.
SUDO=("sudo")
[[ -n "$SUDO_ASKPASS" ]] && SUDO=("sudo" "-A")

"${SUDO[@]}" echo "Authenticated." || exit

# It won't find paths not staged, we git add .
git add .

# ---- Host selection (only needed for nix rebuild) ----
if $do_nix; then
    if [[ "$HOSTNAME" = "nixos" ]] || $reconfigure; then
        echo -n "Enter Host: "
        read -r host
    else
        host=$HOSTNAME
    fi
fi

# ---- Metered-connection guard (data saver) ----
# On the "verse" phone hotspot (or any metered uplink), skip `nix flake update`:
# repinning against unstable pulls multi-GB from cache.nixos.org. The rebuild
# then reuses the existing lock and is nearly download-free.
metered=false
if [[ -e /run/data-saver ]]; then
    metered=true
elif command -v nmcli >/dev/null 2>&1; then
    if nmcli -t -f NAME connection show --active 2>/dev/null | grep -qx "verse"; then
        metered=true
    else
        while IFS= read -r dev; do
            [[ -z "$dev" || "$dev" == "lo" ]] && continue
            if nmcli -t -f GENERAL.METERED device show "$dev" 2>/dev/null | grep -q 'METERED:yes'; then
                metered=true
                break
            fi
        done < <(nmcli -t -f DEVICE connection show --active 2>/dev/null)
    fi
fi
$metered && echo "⚠  Metered connection detected — skipping 'nix flake update' to save data."

# ---- Nix rebuild (dotfiles are deployed via system.activationScripts.dotfiles) ----
if $do_nix; then
    # Update flake.lock (make sure it's synced up, can fail but should be fine)
    $metered || "${SUDO[@]}" nix flake update

    # It won't find paths not staged, we git add .
    git add .

    # Apply the updates
    "${SUDO[@]}" nixos-rebuild switch --flake "./#$host" --impure

    # It won't find paths not staged, we git add .
    git add .

    # Update flake.lock (required again to update after package install)
    $metered || nix flake update

    df -h /boot

    # Reload Hyprland so any new keybinds / windowrules in dotfiles take
    # effect without dropping the user back onto a stock-default layout.
    # Skipped on hosts without Hyprland (ace, chrono).
    if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        hyprctl reload
    fi
fi

# ---- Proactively configure secure-askpass if missing ----
# Lets `sudo -A` work in non-TTY shells (Claude Code's `!`, scripts, etc.)
# without weakening sudoers. Prompts only when no encrypted password file exists.
askpass_manager="$HOME/.local/share/secure-askpass/askpass-manager"
if [[ -x "$askpass_manager" ]] \
   && [[ ! -e "$HOME/.sudo_askpass.age" ]] \
   && [[ ! -e "$HOME/.sudo_askpass.ssh" ]]; then
    echo
    echo "secure-askpass isn't configured yet — setting it up now so \`sudo -A\` works."
    "$askpass_manager" set
fi
