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
    environmentFile = "/home/jorge/.config/phonetic/config.env";
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

  # games
  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  programs.fish.shellAliases = {
    avante = "nvim -c 'lua vim.defer_fn(function()require(\"avante.api\").zen_mode()end, 100)'";
  };

  # System-wide program configurations (converted from home-manager)
  environment.systemPackages = with pkgs; [
    # games
    (heroic.override {
      extraPkgs = pkgs: [
        pkgs.gamescope
      ];
    })
    bitwarden-cli
    git # Flakes use Git to pull dependencies from data sources, so Git must be installed first
    libgcc
    wget
    curl
    libsecret

    wifite2
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
    powertop # battery usage monitoring

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

    playerctl # managing eww music
    pulsemixer # TUI audio device and volume control
    speechd
    eww
    waybar
    libreoffice-fresh
    dbeaver-bin
    obsidian # Update nevermind is was flake.nix shit <-- Update R.I.P <-- Update WE'RE SO BACK <-- I'm sorry little one, you were too trash for me to try to figure out. https://github.com/NixOS/nixpkgs/issues/302457
    bitwarden-desktop # Update WE'RE SO BACK <-- I believed in you, but you had to be a pain.
    vscode
    (pkgs.symlinkJoin {
      name = "google-chrome";
      paths = [ pkgs.google-chrome ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/google-chrome-stable \
          --add-flags "--remote-debugging-port=9222"
      '';
    })
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
    postgresql
    qbittorrent
    hoppscotch
    anki
    discord
    signal-desktop
    kitty
    mako # notifications
    libnotify # Required by dunst
    tofi # minimalist app launcher
    grim # screenshot utility
    slurp # region selection
    grimblast # hyprland screenshot helper (handles fractional scaling)
    wayshot # zwlr-screencopy based screenshot (works where grim fails)
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

  # Create aliases for vi, vim, and vimdiff
  environment.shellAliases = {
    vi = "nvim";
    vim = "nvim";
    vimdiff = "nvim -d";
  };

  # GitHub CLI configuration
  environment.etc."gh/config.yml".text = ''
    editor: micro
    git_protocol: ssh
    prompt: enabled
  '';
}
