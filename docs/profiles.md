# Profiles Reference

This document describes all available profiles and configuration options.

## Profile Overview

| Profile | Option | Default | Description |
|---------|--------|---------|-------------|
| Base | `my.profiles.base` | `true` | Essential CLI tools, shell config, btop |
| Shell | `my.profiles.shell` | `true` | Bash and Fish shell configuration |
| Terminal | `my.profiles.terminal` | `true` | Kitty terminal emulator |
| Prompt | `my.profiles.prompt` | `true` | Starship prompt configuration |
| Git | `my.profiles.git` | `true` | Git, delta, custom scripts |
| Development | `my.profiles.development` | `false` | Dev tools, language servers, cloud tools |
| Plotting | `my.profiles.plotting` | `false` | gnuplot for visualization |
| Help | `my.profiles.help` | `true` | `hm-help` command |

## Feature Modules

These are enabled separately from profiles:

| Feature | Option | Description |
|---------|--------|-------------|
| 1Password | `my.onePassword.enable` | SSH agent and git signing |
| Secrets | `my.sops.enable` | sops-nix encrypted secrets |
| GNOME | `my.gnome.enable` | Custom keybindings |
| Emacs | `my.emacs.enable` | Emacs daemon and LSP booster |
| Nix Config | `my.nix.enable` | Access tokens, remote builders |
| ROS2 | `my.ros2.enable` | ROS2 sysctl checks |
| Peripherals | `my.peripherals.*` | 3D/label printers |

---

## Base Profile

Essential tools and configuration for all users.

### Packages Installed

- **Modern CLI replacements**: bat, eza, fd, ripgrep, dust
- **Diff tools**: difftastic, dyff
- **Utilities**: fzf, just, lnav, parallel
- **Custom scripts**: nix-size

### Configuration

- XDG directories enabled
- direnv with nix-direnv
- btop system monitor
- GDB and clangd configs

### btop Options

```nix
my.monitoring.btop = {
  updateMs = 500;           # Update interval (ms)
  colorTheme = "Default";   # Color theme
  shownBoxes = "cpu mem net proc";  # Visible boxes
  # ... many more options
};
```

---

## 1Password Profile

SSH agent and git signing integration with 1Password.

### Options

```nix
my.onePassword = {
  enable = true;
  agentSocket = "~/.1password/agent.sock";  # Default
};
```

### Features

- SSH agent socket management
- Git commit signing via `op-ssh-sign`
- CLI plugin support

### Requirements

- 1Password desktop app with SSH agent enabled
- For git signing, set `my.git.signingKey` to your SSH public key

---

## Secrets Profile (sops-nix)

Encrypted secrets management using age encryption.

### Options

```nix
my.sops = {
  enable = true;
  ageKeyFile = "~/.config/sops/age/keys.txt";  # Default
};
```

### Setup

1. Generate an age key:
   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

2. Add your public key to `secrets/.sops.yaml`

3. Edit secrets:
   ```bash
   cd secrets && sops secrets.yaml
   ```

### How It Works

- Secrets stored encrypted in git (`secrets/secrets.yaml`)
- Decrypted on login to `/run/user/<uid>/secrets/`
- Systemd user service handles decryption on boot

---

## Git Profile

Git configuration with signing, delta, and custom scripts.

### Options

```nix
my.git = {
  signingKey = "ssh-ed25519 AAAA...";  # SSH public key for signing
  sshSigningProgram = "op-ssh-sign";   # or "ssh-keygen"
  gitlabUser = null;                   # GitLab username
};
```

### Custom Git Scripts

Available as `git <command>`:

- `git rebase-main` - Rebase current branch on main
- `git cleanup-branches` - Interactive branch cleanup with fzf
- `git list-outdated` - List branches behind main
- `git all-rebase-main` - Rebase all local branches on main

### Signing Without 1Password

```nix
my.git.sshSigningProgram = "ssh-keygen";
```

---

## Development Profile

Comprehensive development tooling.

### Packages Installed

**Language Servers**:
- bash-language-server, clangd, gopls, neocmakelsp
- pyright, python-lsp-server, taplo, nil (Nix)
- emacs-lsp-booster

**Languages**:
- Go, Python tools (ruff, pyright, typos)

**Nix Tools**:
- nix-diff, nix-du, nix-tree, nvd, dix
- nix-output-monitor, deadnix, statix, nixfmt-rfc-style
- cachix, devenv, nix-index, nix-update

**Cloud Tools**:
- azure-cli, kubectl, k9s, terraform, opentofu, tflint, sops

**MCP Servers**:
- github-mcp-server, terraform-mcp-server, mcp-pypi, rime

---

## Shell Profile

Bash and Fish shell configuration.

### Features

- Shell aliases (`hms`, `hmb`, `hme`, etc.)
- Shell functions (`hm-update`, `hm-rollback`, `hm-diff`, `hm-push`)
- PATH configuration (CUDA, cargo, local binaries)
- kubectl completion

---

## Terminal Profile

Kitty terminal emulator configuration.

### Options

```nix
my.terminal.kitty = {
  fontFamily = "JetBrains Mono";
  fontSize = 11;
  # ... appearance options
};
```

---

## Prompt Profile

Starship prompt configuration.

### Options

```nix
my.prompt.starship = {
  showHostname = true;      # Show hostname (SSH only by default)
  showKubernetes = false;   # Show k8s context
  showAws = false;          # Show AWS profile
  showGcloud = false;       # Show GCloud project
  # ... more options
};
```

---

## User Identity

Required for all configurations:

```nix
my.user = {
  name = "username";           # Unix username
  fullName = "Full Name";      # For git commits
  email = "user@example.com";  # Primary email
  homeDirectory = "/home/username";
  uid = "1000";                # Required for sops-nix
};
```

---

## System Commands

Some commands must come from the system (not Nix) due to driver/daemon requirements:

```nix
my.systemCommands = {
  systemctl.path = "/usr/bin/systemctl";    # System D-Bus
  op.path = "/usr/bin/op";                  # Biometric auth
};
```

---

## Path Configuration

Override default paths:

```nix
my.paths = {
  localBin = "$HOME/.local/bin";
  cudaHome = "/usr/local/cuda";
  cargoHome = "$HOME/.cargo";
  onePasswordPath = "/opt/1Password";
  homeManagerFlakePath = "~/code/nix/nix-home";
};
```
