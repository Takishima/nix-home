# Installation Guide

Complete setup instructions for this Home Manager configuration.

## Prerequisites

### Install Nix

**Recommended: Determinate Systems Installer**

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

This automatically enables flakes and configures best practices.

**Alternative: Official Nix Installer**

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

Then enable flakes by adding to `~/.config/nix/nix.conf`:

```
experimental-features = nix-command flakes
```

## Setup

### 1. Clone the Repository

```bash
mkdir -p ~/code/nix
cd ~/code/nix
git clone <your-repo-url> nix-home
cd nix-home
```

### 2. Create Your User Configuration

```bash
cp users/example.nix users/$(whoami).nix
```

Edit `users/$(whoami).nix`:

```nix
{
  my = {
    user = {
      name = "yourname";
      fullName = "Your Full Name";
      email = "your.email@example.com";
      homeDirectory = "/home/yourname";
      uid = "1000";  # Required for sops-nix
    };

    # Enable features as needed
    onePassword.enable = false;

    profiles = {
      base = true;
      development = true;
    };
  };
}
```

### 3. Add to flake.nix

```nix
homeConfigurations = {
  "yourname" = mkUser { modules = [ ./users/yourname.nix ]; };
};
```

### 4. Build and Activate

```bash
nix build .#homeConfigurations.yourname.activationPackage
./result/activate
```

### 5. Reload Shell

```bash
source ~/.bashrc  # or restart terminal
```

The `home-manager` CLI is now available via `programs.home-manager.enable`.

> **Warning**: Do not install home-manager via `nix profile install` - it will conflict.

## Common Operations

### Apply Configuration

```bash
# Using alias (after first activation)
hms

# Or explicitly
home-manager switch --flake ~/code/nix/nix-home#yourname

# Or bootstrap method (no home-manager CLI needed)
nix build .#homeConfigurations.yourname.activationPackage && ./result/activate
```

### Test Before Applying

```bash
nix build .#homeConfigurations.yourname.activationPackage
nvd diff ~/.local/state/nix/profiles/home-manager ./result
```

### Update Packages

```bash
nix flake update
hms
git add flake.lock && git commit -m "flake: Update inputs"
```

### Rollback

```bash
home-manager generations  # List available
home-manager switch --flake . --rollback
```

## Secrets Management (sops-nix)

Secrets are encrypted with [age](https://github.com/FiloSottile/age) and managed by [sops-nix](https://github.com/Mic92/sops-nix).

### Initial Setup (New Machine)

1. **Generate an age key:**

   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

1. **Get your public key:**

   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   # Output: age1abc123...
   ```

1. **Add to `secrets/.sops.yaml`:**

   ```yaml
   keys:
     - &laptop age1abc123...
     - &newmachine age1xyz...   # Add your key
   creation_rules:
     - path_regex: secrets\.yaml$
       key_groups:
         - age:
             - *laptop
             - *newmachine      # Reference it here
   ```

1. **Re-encrypt secrets:**

   ```bash
   cd secrets
   sops updatekeys secrets.yaml
   ```

### Editing Secrets

```bash
cd secrets
sops secrets.yaml  # Opens in $EDITOR, saves encrypted
```

### Secrets Format

```yaml
nix_access_tokens: |
    access-tokens = github.com=ghp_xxx gitlab.com=glpat-xxx

netrc: |
    machine cachix.org login token password xxx
```

Secrets are decrypted at activation to `/run/user/<uid>/secrets/` (tmpfs, never in Nix store).

## Machine Variants

For machines with different requirements (e.g., no 1Password on Jetson):

```nix
# users/yourname-jetson.nix
{ lib, ... }:
{
  imports = [ ./yourname.nix ];

  my = {
    user.uid = "1001";
    onePassword.enable = lib.mkForce false;
    git.sshSigningProgram = lib.mkForce "ssh-keygen";
  };
}
```

Add to flake.nix:

```nix
"yourname-aarch64" = mkUser {
  system = "aarch64-linux";
  modules = [ ./users/yourname-jetson.nix ];
};
```

## Troubleshooting

### "command not found: home-manager"

Restart your shell after activation. If still missing:

```bash
nix build .#homeConfigurations.yourname.activationPackage && ./result/activate
```

### "experimental Nix feature 'nix-command' is disabled"

Add to `~/.config/nix/nix.conf`:

```
experimental-features = nix-command flakes
```

Restart nix-daemon: `sudo systemctl restart nix-daemon`

### Build fails with "Git tree is dirty"

This is a warning. Either commit changes or use `--impure`:

```bash
home-manager switch --flake .#yourname --impure
```

### Changes don't take effect

1. Restart terminal or `source ~/.bashrc`
1. Check build succeeded without errors
1. Verify correct user configuration name

## Notes

- **1Password**: Requires desktop app with SSH agent enabled
- **Git signing without 1Password**: Use `my.git.sshSigningProgram = "ssh-keygen"`
- **SSH external config**: Add `Include config.d/*` at top of `~/.ssh/config`

## Further Reading

- [Profiles Reference](profiles.md) - Available profiles and configuration options
- [Commands Reference](commands.md) - Unified command system and available commands
- [User Configuration](personal-module.md) - Creating custom user configurations
