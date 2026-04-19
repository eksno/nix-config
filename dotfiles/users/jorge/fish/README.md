# Fish Shell Configuration

This directory contains the configuration files for the Fish shell.

## Structure

- `config.fish`: Main configuration file that loads all other config files.
- `fish_variables`: Universal variables for the Fish shell.
- `conf.d/`: Directory for configuration modules:
  - `aliases.fish`: Command aliases and shortcuts.
  - `environment.fish`: Environment variables.
  - `nix_config.fish`: NixOS specific configuration.
- `functions/`: Directory for Fish functions:
  - `n.fish`: Shortcut for nvim.
  - `envsource.fish`: Function to source environment variables from a file.
  - `fish_prompt.fish`: Custom prompt function.
- `completions/`: Directory for Fish completions.

## Features

- Auto-start tmux when opening a new shell
- Intelligent command aliases with availability checking
- Custom prompt with git status
- Environment variables for various programming languages
- NixOS specific settings
- Direnv and nix-direnv integration
- Enhanced directory navigation

## Installation

This configuration is automatically linked by `./update.sh symlink` from the nix-config repository.

```bash
# Create the dotfile symlinks
~/nix-config/update.sh symlink
```

## Dependencies

The configuration works best with these tools installed:
- fish
- bat
- eza
- btop
- git
- tmux
- direnv
- nvim

## Customization

To add custom Fish configuration:
1. Add shell aliases to `conf.d/aliases.fish`
2. Add environment variables to `conf.d/environment.fish`
3. Add Fish functions to the `functions/` directory

To reload the configuration, run `reload` in your Fish shell. 