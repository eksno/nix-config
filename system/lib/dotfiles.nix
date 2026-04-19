{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles;
  user = cfg.username;
  repoPath = "/home/${user}/nix-config";
  defaultPath = "${repoPath}/dotfiles/default";
  overridePath = "${repoPath}/dotfiles/users/${user}";

  # Resolve source: user override if present, otherwise default.
  # Matches the old symlink.sh link_config() logic.
  resolve = app: ''
    if [ -e "${overridePath}/${app}" ]; then
      _src="${overridePath}/${app}"
    else
      _src="${defaultPath}/${app}"
    fi
  '';

  # Symlink an entire directory (for read-only app configs).
  linkDir = app: target: ''
    ${resolve app}
    ln -sfn "$_src" "${target}"
  '';

  # Symlink individual files within a directory (for apps that write back).
  linkFiles = app: target: globs: ''
    ${resolve app}
    ${lib.concatMapStringsSep "\n" (g: ''
      for f in "$_src"/${g}; do
        [ -e "$f" ] && ln -sf "$f" "${target}/$(${pkgs.coreutils}/bin/basename "$f")"
      done
    '') globs}
  '';

in
{
  options.dotfiles.username = lib.mkOption {
    type = lib.types.str;
    description = "Primary user whose dotfiles are deployed by the activation script.";
  };

  config = lib.mkIf (cfg.username != "") {
    system.activationScripts.dotfiles = {
      text = ''
        # Guard: skip if repo isn't cloned yet (fresh install).
        [ -d "${repoPath}/dotfiles" ] || exit 0

        cfg="/home/${user}/.config"
        mkdir -p "$cfg"

        # ── Fish (file-level: fish writes fish_variables & completions) ──
        # If fish/tmux are old-style directory symlinks, replace with real dirs.
        [ -L "$cfg/fish" ] && rm -f "$cfg/fish"
        [ -L "$cfg/tmux" ] && rm -f "$cfg/tmux"
        mkdir -p "$cfg/fish/conf.d" "$cfg/fish/functions" "$cfg/fish/completions"
        ${resolve "fish"}
        ln -sf "$_src/config.fish" "$cfg/fish/config.fish"
        for f in "$_src/conf.d/"*.fish; do
          [ -e "$f" ] && ln -sf "$f" "$cfg/fish/conf.d/$(${pkgs.coreutils}/bin/basename "$f")"
        done
        for f in "$_src/functions/"*.fish; do
          [ -e "$f" ] && ln -sf "$f" "$cfg/fish/functions/$(${pkgs.coreutils}/bin/basename "$f")"
        done
        for f in "$_src/completions/"*.fish; do
          [ -e "$f" ] && ln -sf "$f" "$cfg/fish/completions/$(${pkgs.coreutils}/bin/basename "$f")"
        done
        chown -R ${user}:users "$cfg/fish" 2>/dev/null || true

        # ── Tmux (file-level: TPM writes to plugins/) ──
        mkdir -p "$cfg/tmux/plugins"
        ${resolve "tmux"}
        ln -sf "$_src/tmux.conf" "$cfg/tmux/tmux.conf"
        ln -sf "$_src/tmux-nerd-font-window-name.yml" "$cfg/tmux/tmux-nerd-font-window-name.yml"
        # Bootstrap TPM if missing
        if [ ! -d "$cfg/tmux/plugins/tpm" ]; then
          ${pkgs.git}/bin/git clone --depth 1 \
            https://github.com/tmux-plugins/tpm \
            "$cfg/tmux/plugins/tpm" 2>/dev/null || true
        fi
        chown -R ${user}:users "$cfg/tmux" 2>/dev/null || true

        # ── Read-only apps (directory-level symlinks) ──
        ${linkDir "nvim" "$cfg/nvim"}
        ${linkDir "kitty" "$cfg/kitty"}
        ${linkDir "mako" "$cfg/mako"}
        ${linkDir "btop" "$cfg/btop"}
        ${linkDir "tofi" "$cfg/tofi"}
        ${linkDir "waybar" "$cfg/waybar"}
        ${linkDir "xdg-desktop-portal" "$cfg/xdg-desktop-portal"}

        # ── Locals ──
        mkdir -p "/home/${user}/.local/share"
        ${linkDir "icons" "/home/${user}/.local/share/icons"}
        ln -sfn /run/current-system/sw/share/X11/fonts "/home/${user}/.local/share/fonts"

        # ── Hyprland (sub-dir symlinks + compose hyprland.conf) ──
        mkdir -p "$cfg/hypr"
        ln -sfn "${defaultPath}/hypr/hosts" "$cfg/hypr/hosts"
        ln -sfn "${defaultPath}/hypr/users" "$cfg/hypr/users"
        ln -sfn "${defaultPath}/hypr/shared" "$cfg/hypr/shared"
        rm -f "$cfg/hypr/hyprland.conf"
        _hostname="$(${pkgs.hostname}/bin/hostname)"
        echo "source = ~/.config/hypr/users/${user}/default.conf" > "$cfg/hypr/hyprland.conf"
        echo "source = ~/.config/hypr/hosts/$_hostname/default.conf" >> "$cfg/hypr/hyprland.conf"
        chown -h ${user}:users "$cfg/hypr/hyprland.conf" 2>/dev/null || true

        # ── Root config ──
        rm -rf /root/.config
        mkdir -p /root/.config
        ln -sfn /home/${user}/.config /root/.config
      '';
      deps = [ "users" ];
    };
  };
}
