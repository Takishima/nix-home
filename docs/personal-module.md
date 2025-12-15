# User Configuration Guide

Guide for creating and customizing your own user configuration.

## Quick Start

```bash
# 1. Create your config file
cp users/example.nix users/$(whoami).nix

# 2. Edit with your details
$EDITOR users/$(whoami).nix

# 3. Add to flake.nix
# "yourname" = mkUser { modules = [ ./users/yourname.nix ]; };

# 4. Build and activate
nix build .#homeConfigurations.yourname.activationPackage
./result/activate
```

## Required Configuration

Every user config must define:

```nix
# users/yourname.nix
{ ... }:
{
  my.user = {
    name = "yourname";              # Unix username
    fullName = "Your Full Name";    # For git commits
    email = "you@example.com";      # Primary email
    homeDirectory = "/home/yourname";
    uid = "1000";                   # Required for sops-nix
  };
}
```

## Optional Features

### Git Signing

```nix
my.git = {
  signingKey = "ssh-ed25519 AAAA...";  # Your SSH public key
  sshSigningProgram = "op-ssh-sign";   # or "ssh-keygen"
};
```

### 1Password Integration

```nix
my.onePassword.enable = true;
```

Requires 1Password desktop app with SSH agent enabled.

### Secrets Management

```nix
my.sops.enable = true;
```

See [Installation Guide](installation.md#secrets-management-sops-nix) for setup.

### Profile Selection

```nix
my.profiles = {
  base = true;         # Essential tools (default: true)
  development = true;  # Dev tools, LSPs
  plotting = false;    # gnuplot
};
```

See [Profiles Reference](profiles.md) for all options.

## SSH Configuration

Add SSH hosts directly in your user config:

```nix
programs.ssh.matchBlocks = {
  "my-server" = {
    hostname = "192.168.1.100";
    user = "myuser";
    identityFile = "~/.ssh/mykey";
    identitiesOnly = true;
    forwardAgent = true;
  };
};
```

## Custom Commands

Add your own commands to the unified registry:

```nix
my.commands.aliases.myalias = {
  desc = "My custom alias";
  command = "echo 'Hello!'";
};
```

See [Commands Reference](commands.md) for more examples.

## Machine Variants

Create variants for different machines (e.g., no 1Password on a server):

```nix
# users/yourname-server.nix
{ lib, ... }:
{
  imports = [ ./yourname.nix ];

  my = {
    onePassword.enable = lib.mkForce false;
    git.sshSigningProgram = lib.mkForce "ssh-keygen";
  };
}
```

Add to flake.nix:

```nix
"yourname-server" = mkUser {
  modules = [ ./users/yourname-server.nix ];
};

# For different architectures
"yourname-aarch64" = mkUser {
  system = "aarch64-linux";
  modules = [ ./users/yourname-server.nix ];
};
```

## Organizing Large Configs

Split into multiple files:

```
users/
├── yourname.nix           # Main config
└── yourname/
    ├── ssh.nix            # SSH hosts
    ├── gnome.nix          # GNOME keybindings
    └── keys/
        └── github.pub     # SSH public keys
```

Import in main config:

```nix
# users/yourname.nix
{ ... }:
{
  imports = [
    ./yourname/ssh.nix
    ./yourname/gnome.nix
  ];

  my.user = { ... };
}
```
