# Commands Reference

This document describes the unified command system and all available commands.

## Overview

All custom commands are defined in a unified registry (`my.commands.*`) that:
- Generates shell aliases for both bash and fish
- Generates git aliases and installs git scripts
- Automatically creates help text for `hm-help`
- Eliminates duplicated command/help definitions

## Using hm-help

After activation, run `hm-help` to see all available commands:

```bash
hm-help          # Show scripts, aliases, functions
hm-help --all    # Include git commands
hm-help --git    # Show only git commands
```

---

## Home Manager Commands

### Core Commands

| Command | Description |
|---------|-------------|
| `hms` | Switch to new home-manager configuration |
| `hmb` | Build configuration without switching |
| `hme` | Open home-manager config in editor |
| `hm-update` | Pull repo and switch (validates clean working tree) |
| `hm-rollback` | Select and activate previous generation (with fzf) |
| `hm-diff` | Show derivation diff between current and new build |
| `hm-push` | Push current generation to cachix (if configured) |
| `hm-help` | Show all custom commands |

### Nix Commands

| Command | Description |
|---------|-------------|
| `clean-nix` | Garbage collect nix store (7 day retention) |
| `nix-show-gc` | Show nix garbage collection roots |
| `nix-size` | Show NAR and closure sizes for store paths |

---

## Git Commands

Custom git scripts available as `git <command>`:

| Command | Description |
|---------|-------------|
| `git rebase-main` | Rebase current branch on main |
| `git cleanup-branches` | Interactive branch cleanup with fzf |
| `git list-outdated` | List branches behind main |
| `git all-rebase-main` | Rebase all local branches on main |

---

## Shell Aliases

| Alias | Description |
|-------|-------------|
| `l` | eza with icons and long format |
| `k` | kubectl shorthand |
| `dr` | Direnv reload |
| `emacs` | Emacs client (terminal mode) |
| `pcs` | Build pre-commit config from flake |
| `apt-all-update` | Update all package managers |

---

## Unified Command Registry

Commands are defined in modules using `my.commands.*`. This single-source-of-truth pattern ensures:

1. **No duplication** - Command and help text defined once
2. **Multi-shell support** - Bash and fish generated automatically
3. **Discoverability** - All commands visible via `hm-help`

### Command Types

#### Aliases

Simple command substitutions:

```nix
my.commands.aliases = {
  hms = {
    desc = "home-manager switch";
    command = "home-manager switch --flake ~/config#user";
  };
};
```

#### Git Aliases

Git-specific aliases (added to `~/.gitconfig`):

```nix
my.commands.gitAliases = {
  st = {
    desc = "Short status";
    command = "status -s";
  };
};
```

#### Git Scripts

Standalone scripts invoked as `git <name>`:

```nix
my.commands.gitScripts = {
  rebase-main = {
    desc = "Rebase branch on main";
    package = myGitRebaseScript;
  };
};
```

#### Scripts

Non-git standalone scripts:

```nix
my.commands.scripts = {
  nix-size = {
    desc = "Show NAR and closure sizes";
    package = nixSizeScript;
    section = "Nix";  # Optional grouping in help
  };
};
```

#### Functions

Complex shell functions with separate bash/fish implementations:

```nix
my.commands.functions = {
  hm-update = {
    desc = "Pull and switch";
    bash = ''
      # bash implementation
      git -C "$hm_path" pull --ff-only
      home-manager switch --flake "$hm_path#user"
    '';
    fish = ''
      # fish implementation
      git -C "$hm_path" pull --ff-only
      home-manager switch --flake "$hm_path#user"
    '';
  };
};
```

---

## Adding Custom Commands

To add your own commands, define them in your user config:

```nix
# users/yourname.nix
{ config, pkgs, ... }:

let
  myScript = pkgs.writeShellScriptBin "my-script" ''
    echo "Hello from my script!"
  '';
in
{
  my.commands.aliases.myalias = {
    desc = "My custom alias";
    command = "echo 'Hello!'";
  };

  my.commands.scripts.my-script = {
    desc = "My custom script";
    package = myScript;
  };
}
```

After running `hms`, your commands will be available and visible in `hm-help`.
