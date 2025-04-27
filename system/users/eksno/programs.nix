{ system, inputs, config, pkgs, ... }:
{
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [

    ];

    # System-wide program configurations (converted from home-manager)
    environment.systemPackages = with pkgs; [
        inputs.zen-browser.packages."${system}".default
        neofetch # :)
        nnn # tui file manager
        lazygit # tui for git
        autojump

        # archives
        zip
        xz
        unzip
        p7zip

        # language related
        nodePackages.pnpm
        nodejs_20
        bun
        gnumake
        cargo
        rustc

        # dev
        cz-cli
        pre-commit

        # utils
        openvpn
        gdb
        ripgrep # recursively searches directories for a regex pattern
        jq # A lightweight and flexible command-line JSON processor
        yq-go # yaml processer https://github.com/mikefarah/yq
        fzf # A command-line fuzzy finder
        fd
        pinentry
        xorg.libxcvt # for screen sizing
        cmake
        imagemagick
        acpi # Power
        lsof # List open files
        bluetuith

        # networking tools
        mtr # A network diagnostic tool
        iperf3
        dnsutils  # `dig` + `nslookup`
        ldns # replacement of `dig`, it provide the command `drill`
        aria2 # A lightweight multi-protocol & multi-source command-line download utility
        socat # replacement of openbsd-netcat
        nmap # A utility for network discovery and security auditing
        ipcalc  # it is a calculator for the IPv4/v6 addresses

        playerctl # managing eww music
        pulsemixer # TUI audio device and volume control
        speechd
        eww
        waybar
        libreoffice
        helvum
        dbeaver-bin
        obsidian # Update nevermind is was flake.nix shit <-- Update R.I.P <-- Update WE'RE SO BACK <-- I'm sorry little one, you were too trash for me to try to figure out. https://github.com/NixOS/nixpkgs/issues/302457
        bitwarden  # Update WE'RE SO BACK <-- I believed in you, but you had to be a pain.
        vscode
        obs-studio
        google-chrome
        easyeffects
        lm_sensors
        docker-compose
        steam
        v4l-utils
        beeper
        whisper-ctranslate2
        tmux
        code-cursor
        vivaldi
        seahorse
        brightnessctl
        axel
        glib
        btop
        google-chrome
        postgresql
        qbittorrent
        hoppscotch
        obs-studio
        gource
        anki
        easyeffects
        discord
        kitty
        dunst # notifications
        libnotify # Required by dunst
        tofi # minimalist app launcher
        grim # screenshot utility
        slurp # region selection
        swww # wallpaper engine
        mpvpaper # wallpaper video engine / possibly can remove this
        lz4 # helps swww
        waypaper # gui wallpaper setter / possibly can remove this
        xdg-utils # commands for xdg, setting default apps and such
        ipcalc  # it is a calculator for the IPv4/v6 addresses

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
