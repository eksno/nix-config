{ pkgs, config, lib, ... }:
{
    config = {
        home.packages = with pkgs; [
            sesh
        ];

        programs.tmux = {
        enable = true;
        shell = "${pkgs.fish}/bin/fish";
        terminal = "tmux-256color";
        historyLimit = 100000;
        keyMode = "vi";
        prefix = "C-a";
        sensibleOnTop = true;
        mouse = true;

        plugins = with pkgs.tmuxPlugins; [
            # NOTE: catppuccin should always be first
            {
                plugin = catppuccin;
                extraConfig = ''
                    set -g @catppuccin_flavour 'mocha'
                    set -g @catppuccin_window_left_separator "█"
                    set -g @catppuccin_window_right_separator "█ "
                    set -g @catppuccin_window_middle_separator " █"
                    set -g @catppuccin_window_number_position "right"

                    set -g @catppuccin_window_default_fill "number"
                    set -g @catppuccin_window_default_text "#W"

                    set -g @catppuccin_window_current_fill "number"
                    set -g @catppuccin_window_current_text "#W"

                    set -g @catppuccin_status_modules "application session user host battery date_time"
                    set -g @catppuccin_status_left_separator  ""
                    set -g @catppuccin_status_right_separator ""
                    set -g @catppuccin_status_right_separator_inverse "no"
                    set -g @catppuccin_status_fill "icon"
                    #set -g @catppuccin_status_connect_separator "no"

                    set -g @catppuccin_directory_text "#{pane_current_path}"
                '';
            }
            better-mouse-mode
            yank
            battery

            # I haven’t worked out how to restore my nvim session, however.
            # TODO: The resurrect plugin needs a session.vim file to do that
            # NOTE: Ressurect and Continuum must be last plugins
            {
                plugin = resurrect;
                extraConfig = ''
                    set -g @resurrect-strategy-vim 'session'
                    set -g @resurrect-strategy-nvim 'session'
                    set -g @resurrect-capture-pane-contents 'on'
                '';
            }
            {
                plugin = continuum;
                extraConfig = ''
                    set -g @continuum-restore 'on'
                    set -g @continuum-boot 'on'
                    set -g @continuum-save-interval '10'
                '';
            }
      ];
      extraConfig = ''
        set -ag terminal-overrides ",xterm-256color:RGB"

        # Quicker escape in neovim
        set -sg escape-time 0
        set-option -g set-titles on
        set-option -g set-titles-string "#S / #W"

        # Change splits to match nvim and easier to remember
        # Open new split at cwd of current split
        unbind %
        unbind '"'
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"

        # Use vim keybindings in copy mode
        set-window-option -g mode-keys vi

        # v in copy mode starts making selection
        bind-key -T copy-mode-vi v send-keys -X begin-selection
        bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
        bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

        # Escape turns on copy mode
        bind Escape copy-mode

        # Easier reload of config
        bind r source-file ~/.config/tmux/tmux.conf

        set-option -g status-position top

        # make Prefix p paste the buffer.
        unbind p
        bind p paste-buffer

        set -g allow-passthrough on
        set -ga update-environment TERM
        set -ga update-environment TERM_PROGRAM

        bind-key -T copy-mode-vi M-h resize-pane -L 1
        bind-key -T copy-mode-vi M-j resize-pane -D 1
        bind-key -T copy-mode-vi M-k resize-pane -U 1
        bind-key -T copy-mode-vi M-l resize-pane -R 1

        # Bind Keys
        bind-key -T prefix C-g split-window \
        	"$SHELL --login -i -c 'navi --print | head -c -1 | tmux load-buffer -b tmp - ; tmux paste-buffer -p -t {last} -b tmp -d'"
        bind-key -T prefix C-l switch -t notes
        bind-key -T prefix C-d switch -t dotfiles
        bind-key e send-keys "tmux capture-pane -p -S - | nvim -c 'set buftype=nofile' +" Enter

        # Status bar
        # set -g status-right 'Batt: #{battery_icon} #{battery_percentage} #{battery_remain} | %a %h-%d %H:%M '
      '';
    };
  };
}
