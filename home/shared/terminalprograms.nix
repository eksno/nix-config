{ config, lib, pkgs, ... }:

{
  programs = {
    bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [
        batwatch
        prettybat
      ];
    };
    bottom = {
      enable = true;
      settings = {
        colors = {
          high_battery_color = "green";
          medium_battery_color = "yellow";
          low_battery_color = "red";
        };
        disk_filter = {
          is_list_ignored = true;
          list = [ "/dev/loop" ];
          regex = true;
          case_sensitive = false;
          whole_word = false;
        };
        flags = {
          dot_marker = false;
          enable_gpu_memory = true;
          group_processes = true;
          hide_table_gap = true;
          mem_as_value = true;
          tree = true;
        };
      };
    };
    dircolors = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv = {
        enable = true;
      };
    };
    eza = {
      enable = true;
      enableAliases = true;
      icons = true;
    };
    # fish = {
    #   enable = true;
    #   shellAliases = {
    #     cat = "bat --paging=never --style=plain";
    #     htop = "btm --basic --tree --hide_table_gap --dot_marker --mem_as_value";
    #     ip = "ip --color --brief";
    #     less = "bat --paging=always";
    #     more = "bat --paging=always";
    #     top = "btm --basic --tree --hide_table_gap --dot_marker --mem_as_value";
    #     tree = "eza --tree";
    #   };
    # };
    gh = {
      enable = true;
      extensions = with pkgs; [ gh-markdown-preview ];
      settings = {
        editor = "micro";
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };
    git = {
      enable = true;
      lfs.enable = true;
      delta = {
        enable = true;
        options = {
          features = "decorations";
          navigate = true;
          side-by-side = true;
        };
      };
      aliases = {
        # Need to decide fav log
        prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        root = "rev-parse --show-toplevel";
      };
      extraConfig = {
        pull.rebase = true;
        credential.helper = "store"; # want to make this more secure
        branch.autosetuprebase = "always";
        color.ui = true;
        core.askPass = ""; # needs to be empty to use terminal for ask pass
        push.default = "tracking";
        init.defaultBranch = "alpha";
      };
      ignores = [
        "*.log"
        "*.out"
        ".DS_Store"
        "bin/"
        "dist/"
        "result"
      ];
    };
    gpg.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
    };
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    neofetch # :)
    nnn # tui file manager
    lazygit # tui for git

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


    # rust
    cargo
    rustc

    # utils
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

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils  # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc  # it is a calculator for the IPv4/v6 addresses
  ];
}
