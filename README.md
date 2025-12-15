# nix-home

Modular Home Manager configuration for non-NixOS systems using Nix flakes.

## Quick Start

```bash
# 1. Create your config
cp users/example.nix users/$(whoami).nix
# Edit with your details

# 2. Add to flake.nix homeConfigurations
"yourname" = mkUser { modules = [ ./users/yourname.nix ]; };

# 3. Build and activate
nix build .#homeConfigurations.yourname.activationPackage
./result/activate
```

## Structure

```
├── flake.nix          # Entry point, inputs, user definitions
├── lib/mkUser.nix     # Factory function for user configs
├── modules/profiles/  # Feature modules (core, base, shell, etc.)
├── overlays/          # Package customizations and patches
├── secrets/           # Encrypted secrets (sops-nix + age)
└── users/             # Per-user configurations
```

## Commands

After activation, run `hm-help` to see all available commands:

```bash
hm-help          # Show scripts, aliases, functions
hm-help --all    # Include git aliases
```

Key commands: `hms` (switch), `hmb` (build), `hm-update`, `hm-rollback`

## Documentation

- [Installation Guide](docs/installation.md) - Prerequisites, setup, troubleshooting
- [User Configuration](docs/personal-module.md) - Creating your own config
- [Profiles Reference](docs/profiles.md) - Available profiles and options
- [Commands Reference](docs/commands.md) - Unified command system
