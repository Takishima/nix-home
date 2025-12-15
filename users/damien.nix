# Damien's Home Manager configuration
# Personal setup with common development features
{ ... }:

{
  imports = [
    ./damien/gnome.nix
  ];

  my = {
    # User identity
    user = {
      name = "damien";
      fullName = "Damien Nguyen";
      email = "damien@example.com"; # TODO: Set your personal email
      homeDirectory = "/home/damien";
      uid = "1000";
    };

    # Git signing and credentials
    git = {
      signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE95iw9Nt7PlxlzGDvRVSHonzEX+xA1oh36o40DVzbO/";
    };

    # NVIDIA GPU support (update version when driver changes)
    nvidia = {
      enable = true;
      driverVersion = "580.105.08";
      driverHash = "sha256-2cboGIZy8+t03QTPpp3VhHn6HQFiyMKMjRdiV2MpNHU=";
    };

    # Path configuration (explicit overrides to prevent future default changes)
    paths = {
      localBin = "$HOME/.local/bin";
      localNgcCli = "$HOME/.local/ngc-cli";
      cargoHome = "$HOME/.cargo";
      cudaHome = "/usr/local/cuda";
      onePasswordPath = "/opt/1Password";
      gitConfigDir = "~/.config/git"; # Git expands ~ to home directory
      gitGlobalIgnore = "~/.gitignore"; # Git expands ~ to home directory
      opConfigDir = "$HOME/.config/op";
    };

    # 1Password integration (SSH agent, git signing)
    onePassword.enable = true;

    # sops-nix secrets management
    sops.enable = true;

    # Nix configuration (uses sops-nix for secrets)
    nix.enable = true;

    # GNOME keybindings (tdrop, emacs-multiscreen)
    gnome = {
      enable = true;
      numlockState = true;
    };

    # Emacs tooling (lsp-booster, daemon service)
    emacs = {
      enable = true;
      daemonExecPath = "/snap/bin/emacs";
      daemonEnvironment = [
        "LSP_USE_PLISTS=true"
        "LD_LIBRARY_PATH=/usr/local/lib"
      ];
    };

    # btop customization
    monitoring.btop.colorTheme = "TTY";

    # Profiles
    profiles = {
      base = true;
      development = true;
      plotting = true;
    };
  };
}
