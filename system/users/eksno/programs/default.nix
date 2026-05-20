{
  system,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./obs.nix
  ];

  nixpkgs.overlays = [ inputs.phonetic.overlays.default ];

  services.phonetic = {
    enable = true;
    environmentFile = "/home/eksno/.config/phonetic/config.env";
  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    libsecret
  ];

  # file manager auto mount usb
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.devmon.enable = true;

  # app repo
  services.flatpak.enable = true;

  # System-wide program configurations (converted from home-manager)
  environment.systemPackages = with pkgs; [
    bitwarden-cli
    git # Flakes use Git to pull dependencies from data sources, so Git must be installed first
    libgcc
    wget
    curl
    libsecret

    # wifite2 — disabled while wireshark-cli source hash is broken upstream
    # in nixpkgs unstable. Uncomment once nixpkgs ships a working revision.
    # See FIXES.md "wireshark-cli source hash mismatch (recurring)".
    # wifite2
    hashcat
    aircrack-ng

    # networking
    mosh
    proton-vpn

    # editor
    neovim
    tree-sitter
    claude-code

    audacity
    powertop # battery usage monitoring (also enabled as service in power-mode module)

    # file manager
    pcmanfm

    inputs.zen-browser.packages."${system}".default
    fastfetch # :)
    nnn # tui file manager
    lazygit # tui for git
    zoxide

    # archives
    zip
    xz
    unzip
    p7zip

    # language related
    pnpm
    nodejs_24
    deno
    bun
    gnumake
    cargo
    rustc
    nixfmt
    onnxruntime # ai stuff idk

    # dev
    cz-cli
    pre-commit

    # utils
    openvpn
    gdb
    bruno
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processer https://github.com/mikefarah/yq
    fzf # A command-line fuzzy finder
    fd
    pinentry-gnome3
    libxcvt # for screen sizing
    cmake
    imagemagick
    acpi # Power
    lsof # List open files
    bluetuith

    # networking tools
    cloudflared

    playerctl # managing eww music
    (pulsemixer.overrideAttrs (old: {
      # Raise the hardcoded 150% cap to 1000%. Combined with the Wireplumber
      # soft-mixer rule on the speaker card (see system/hosts/verse/default.nix),
      # all volume above unity is pure software gain — useful for very quiet
      # source material. Above ~120% on normal masters this WILL clip.
      patches = (old.patches or [ ]) ++ [ ../../../../patches/pulsemixer-max-volume-1000.patch ];
    })) # TUI audio device and volume control
    alsa-utils # alsamixer / amixer / alsactl — direct ALSA controls (CS35L41 knobs)
    speechd
    eww
    waybar
    libreoffice-fresh
    dbeaver-bin
    obsidian # Update nevermind is was flake.nix shit <-- Update R.I.P <-- Update WE'RE SO BACK <-- I'm sorry little one, you were too trash for me to try to figure out. https://github.com/NixOS/nixpkgs/issues/302457
    bitwarden-desktop # Update WE'RE SO BACK <-- I believed in you, but you had to be a pain.
    vscode
    google-chrome
    easyeffects
    lm_sensors
    docker-compose
    v4l-utils
    beeper
    tmux
    code-cursor
    seahorse
    brightnessctl
    axel
    glib
    btop
    google-chrome
    postgresql
    qbittorrent
    hoppscotch
    anki
    easyeffects
    discord
    signal-desktop
    kitty
    mako # notifications
    libnotify # Required by dunst
    tofi # minimalist app launcher
    grim # screenshot utility
    slurp # region selection
    wtype # virtual_keyboard_unstable_v1 typer; used for non-Electron norwegian binds
    xclicker # GUI auto-clicker (X11/XWayland; native Wayland windows aren't clickable)
    age # file encryption, used by secure-askpass for sudo password storage
    awww # wallpaper engine (formerly swww)
    mpvpaper # wallpaper video engine / possibly can remove this
    lz4 # helps awww
    waypaper # gui wallpaper setter / possibly can remove this
    xdg-utils # commands for xdg, setting default apps and such
    ipcalc # it is a calculator for the IPv4/v6 addresses

    # Bat and extras
    bat
    bat-extras.batwatch
    bat-extras.prettybat

    # Direnv
    direnv
    nix-direnv

    # Eza
    eza

    # Git extras
    git-lfs
    delta

    # GitHub CLI and extensions
    gh
    gh-markdown-preview

    # GPG
    gnupg

    # Neovim
    neovim

    # Game Engines
    godot
  ];

  # Git configuration
  programs.git = {
    enable = true;
    lfs.enable = true;
    # Setting global git config
    config = {
      pull.rebase = true;
      credential.helper = "store"; # want to make this more secure
      branch.autosetuprebase = "always";
      color.ui = true;
      core.askPass = ""; # needs to be empty to use terminal for ask pass
      push.default = "tracking";
      init.defaultBranch = "alpha";
      alias = {
        prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        root = "rev-parse --show-toplevel";
      };
      # Set the global gitignore file location
      core.excludesFile = "/etc/gitignore";
    };
  };

  # Create global gitignore file
  environment.etc."gitignore".text = ''
    *.log
    *.out
    .DS_Store
    bin/
    dist/
    result
  '';

  # Configure git-delta separately as a system package
  environment.etc."gitconfig.d/delta".text = ''
    [core]
    pager = delta

    [delta]
    features = decorations
    navigate = true
    side-by-side = true

    [interactive]
    diffFilter = delta --color-only
  '';

  # Neovim as default editor
  environment.variables.EDITOR = "nvim";
  environment.variables.VISUAL = "nvim";

  # secure-askpass: lets `sudo -A` read password from encrypted file so
  # Claude Code / non-TTY shells can run privileged commands.
  # Repo cloned manually to ~/.local/share/secure-askpass (see FIXES.md).
  environment.variables.SUDO_ASKPASS = "/home/eksno/.local/share/secure-askpass/askpass";

  # Create aliases for vi, vim, and vimdiff
  environment.shellAliases = {
    vi = "nvim";
    vim = "nvim";
    vimdiff = "nvim -d";
    cc = "claude";
  };

  # GitHub CLI configuration
  environment.etc."gh/config.yml".text = ''
    editor: micro
    git_protocol: ssh
    prompt: enabled
  '';
}
