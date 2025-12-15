# sops-nix secrets management for standalone home-manager
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.sops;
  userCfg = config.my.user;

  secretsDir = "/run/user/${userCfg.uid}/secrets";
  secretsMountPoint = "/run/user/${userCfg.uid}/secrets.d";
  sopsFileRelative = ../../secrets/secrets.yaml;
  # XDG-compliant path for runtime use in scripts
  # Uses ~/.config/sops/ which is XDG_CONFIG_HOME/sops/
  xdgConfigHome = "${userCfg.homeDirectory}/.config";
  sopsConfigDir = "${xdgConfigHome}/sops";
  sopsFileAbsolute = "${sopsConfigDir}/secrets.yaml";

  # Script to decrypt secrets on login
  decryptSecretsScript = pkgs.writeShellScript "sops-decrypt-secrets" ''
    set -euo pipefail

    AGE_KEY_FILE="${cfg.ageKeyFile}"
    SECRETS_DIR="${secretsDir}"
    SECRETS_MOUNT="${secretsMountPoint}"
    SOPS_FILE="${sopsFileAbsolute}"

    # Check if age key exists
    if [ ! -f "$AGE_KEY_FILE" ]; then
      echo "sops-nix: Age key not found at $AGE_KEY_FILE, skipping secret decryption" >&2
      exit 0
    fi

    # Check if sops file exists
    if [ ! -f "$SOPS_FILE" ]; then
      echo "sops-nix: Secrets file not found at $SOPS_FILE" >&2
      echo "Run 'home-manager switch' to deploy the encrypted secrets file" >&2
      exit 0
    fi

    # Create directories
    mkdir -p "$SECRETS_DIR" "$SECRETS_MOUNT"
    chmod 700 "$SECRETS_DIR" "$SECRETS_MOUNT"

    # Decrypt each secret defined in the sops config
    # Get secret names from sops file and decrypt them
    export SOPS_AGE_KEY_FILE="$AGE_KEY_FILE"

    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: _secret: ''
        echo "Decrypting secret: ${name}"
        SECRET_PATH="$SECRETS_MOUNT/${name}"
        ${lib.getExe pkgs.sops} --decrypt --extract '["${name}"]' "$SOPS_FILE" > "$SECRET_PATH" 2>/dev/null || {
          echo "Warning: Failed to decrypt ${name}" >&2
          continue
        }
        chmod 400 "$SECRET_PATH"
        ln -sf "$SECRET_PATH" "$SECRETS_DIR/${name}"
      '') config.sops.secrets
    )}

    echo "sops-nix: Secrets decrypted successfully"
  '';
in
{
  options.my.sops = {
    enable = lib.mkEnableOption "sops-nix secrets management";

    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "${userCfg.homeDirectory}/.config/sops/age/keys.txt";
      description = "Path to age private key file";
    };
  };

  config = lib.mkIf cfg.enable {
    # Copy encrypted secrets.yaml to a known location for the systemd service
    home.activation.copySopsFile = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      mkdir -p "$(dirname "${sopsFileAbsolute}")"
      cp "${sopsFileRelative}" "${sopsFileAbsolute}"
      chmod 600 "${sopsFileAbsolute}"
    '';

    # Verify UID matches at activation time
    home.activation.checkUid = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      ACTUAL_UID="$(id -u)"
      CONFIGURED_UID="${userCfg.uid}"
      if [ "$ACTUAL_UID" != "$CONFIGURED_UID" ]; then
        echo "ERROR: UID mismatch detected!" >&2
        echo "  Configured UID: $CONFIGURED_UID" >&2
        echo "  Actual UID:     $ACTUAL_UID" >&2
        echo "" >&2
        echo "sops-nix secrets would be written to /run/user/$CONFIGURED_UID/secrets" >&2
        echo "but your user directory is /run/user/$ACTUAL_UID" >&2
        echo "" >&2
        echo "Fix: Set 'my.user.uid = \"$ACTUAL_UID\";' in your user configuration." >&2
        exit 1
      fi
    '';

    # sops base configuration for standalone home-manager
    sops = {
      # Age key configuration
      age = {
        keyFile = cfg.ageKeyFile;
        generateKey = false; # We manage keys manually per-machine
        sshKeyPaths = [ ]; # Don't use SSH keys, use dedicated age key
      };

      # Critical for standalone home-manager (non-NixOS)
      # These paths use /run/user/<uid> which is user-accessible tmpfs
      defaultSymlinkPath = secretsDir;
      defaultSecretsMountPoint = secretsMountPoint;

      # Default settings
      defaultSopsFile = sopsFileRelative;
      defaultSopsFormat = "yaml";

      # Disable GPG (we use age only)
      gnupg.sshKeyPaths = [ ];
    };

    # Systemd user service to decrypt secrets on login
    # This ensures secrets are available after reboot without running home-manager switch
    systemd.user.services.sops-decrypt-secrets = {
      Unit = {
        Description = "Decrypt sops-nix secrets";
        # Run after basic user session is ready
        After = [ "basic.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${decryptSecretsScript}";
        RemainAfterExit = true;
      };
      Install = {
        # Enable by default when home-manager switch runs
        WantedBy = [ "default.target" ];
      };
    };

    # Install sops and age CLI for manual operations
    home.packages = [
      pkgs.sops
      pkgs.age
    ];
  };
}
