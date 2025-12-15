# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a modular Home Manager configuration for non-NixOS systems using Nix flakes. It manages user environment configuration (dotfiles, packages, shell settings) declaratively through Nix.

## Commands

```bash
# Format all files (nix, markdown, shell, yaml, json, toml)
nix fmt

# Build a user configuration
nix build .#homeConfigurations.<username>.activationPackage

# Activate after building
./result/activate

# Check formatting (used in CI)
nix flake check
```

After activation, `hm-help` shows all available commands. Key shortcuts: `hms` (switch), `hmb` (build), `hm-update`, `hm-rollback`.

## Architecture

### Entry Point Flow
`flake.nix` → `lib/mkUser.nix` → profile modules → user module

1. **flake.nix**: Defines inputs (nixpkgs, home-manager, external flakes) and exports `homeConfigurations`
2. **lib/mkUser.nix**: Factory function that creates `homeManagerConfiguration` with all profile modules auto-loaded
3. **modules/profiles/**: Feature modules with `my.*` options (automatically imported by mkUser)
4. **users/**: Per-user configurations that set `my.*` options

### Module Options System

All configuration flows through the `my.*` option namespace defined in `modules/profiles/core.nix`:

- `my.user.*` - User identity (name, email, homeDirectory, uid)
- `my.profiles.*` - Enable/disable feature bundles (base, shell, development, etc.)
- `my.paths.*` - Common path configuration
- `my.commands.*` - Unified command registry (aliases, functions, scripts, gitAliases, gitScripts)
- `my.systemCommands.*` - Non-Nix system binaries with path configuration

### Key Design Patterns

**Profile Modules**: Each profile in `modules/profiles/` guards its configuration with `mkIf cfg.profiles.<name>`. Users enable profiles in their user config.

**Unified Command Registry**: Commands declared in `my.commands.*` automatically generate:
- Shell aliases/functions for bash and fish
- Git aliases and git-* scripts
- Help text for `hm-help` command

**System Commands**: `my.systemCommands` handles binaries that must come from the host system (nvidia-smi, systemctl, op). On non-NixOS, paths are verified during activation.

**Overlays**: `overlays/default.nix` composes individual overlay files. Used for package patches and additions from external flakes.

### Adding New Features

1. Create a profile module in `modules/profiles/` with `my.profiles.<name>` option
2. Import it in `lib/mkUser.nix` module list
3. Users enable via `my.profiles.<name> = true` in their config

## File Formatting

Uses treefmt-nix with: nixfmt-rfc-style (Nix), mdformat (Markdown), shfmt (shell), taplo (TOML), yamlfmt (YAML), prettier (JSON).
