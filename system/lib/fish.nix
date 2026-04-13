{ config, pkgs, ... }:
{
  users.defaultUserShell = pkgs.fish;
  environment.shells = with pkgs; [ fish ];

  # Set up fish as the default shell
  programs.fish.enable = true;

  # Install fish-related packages
  environment.systemPackages = with pkgs; [
    fish
    fishPlugins.done
    fishPlugins.fzf-fish
    fishPlugins.forgit

    # Tools used by the fish config
    direnv
    nix-direnv
    bat
    eza
    btop
    git
    tmux
  ];

  # No need for symlinks as symlink.sh handles this
  # The symlink.sh script creates:
  # ln -s ~/nix-config/dotfiles/default/fish ~/.config/fish

  # Fallback to fish from bash
  # programs.bash.interactiveShellInit = ''
  #     if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
  #     then
  #     shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
  #     exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
  #     fi
  # '';
}
