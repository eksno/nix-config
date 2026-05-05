#!/usr/bin/env bash

# Same as `update.sh` but skips both `nix flake update` calls. Use this for
# the common case of "I changed local config, rebuild against the existing
# flake.lock" — no nixpkgs bump means no closure redownload.
#
# Run `./update.sh` when you actually want to pull upstream package updates.

# Verify not sudo
[[ -z $SUDO_USER ]] && echo "Running" || exit

# ---- Parse args ----
reconfigure=false
for arg in "$@"; do
    case "$arg" in
        reconfigure) reconfigure=true ;;
        *) echo "Unknown arg: $arg" >&2; echo "Usage: $0 [reconfigure]" >&2; exit 1 ;;
    esac
done

# Use `sudo -A` when SUDO_ASKPASS is set (lets non-TTY callers like Claude Code
# authenticate via secure-askpass); fall back to plain `sudo` otherwise.
SUDO=("sudo")
[[ -n "$SUDO_ASKPASS" ]] && SUDO=("sudo" "-A")

"${SUDO[@]}" echo "Authenticated." || exit

# It won't find paths not staged, we git add .
git add .

# ---- Host selection ----
if [[ "$HOSTNAME" = "nixos" ]] || $reconfigure; then
    echo -n "Enter Host: "
    read -r host
else
    host=$HOSTNAME
fi

# ---- Nix rebuild (no flake update) ----
"${SUDO[@]}" nixos-rebuild switch --flake "./#$host" --impure

# It won't find paths not staged, we git add .
git add .

df -h /boot
