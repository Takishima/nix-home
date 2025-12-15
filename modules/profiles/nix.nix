# Nix configuration management - native settings + sops-nix secrets
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.my.nix;
  sopsCfg = config.my.sops;
  userCfg = config.my.user;

  # Static paths that always exist (even if empty)
  # This prevents nix.conf from failing before sops activation
  accessTokensPath = "${userCfg.homeDirectory}/.config/nix/access-tokens.conf";
  netrcPath = "${userCfg.homeDirectory}/.config/nix/netrc";

  # Extract substituters and public keys from caches option
  substituters = lib.attrNames cfg.caches;
  publicKeys = lib.mapAttrsToList (_: cache: cache.publicKey) cfg.caches;

  # Join lists with spaces for nix.conf format
  substitutersStr = lib.concatStringsSep " " substituters;
  publicKeysStr = lib.concatStringsSep " " publicKeys;
in
{
  options.my.nix = {
    enable = mkEnableOption "Nix configuration with sops-nix secrets (access-tokens, netrc)" // {
      default = false;
    };

    cachixCache = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Cachix cache name for hm-push command";
      example = "my-cache";
    };

    nixbuildSshKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "SSH public key file for nixbuild.net remote builder";
      example = "~/.ssh/nixbuild.pub";
    };

    machines = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            uri = mkOption {
              type = types.str;
              description = "SSH URI for the builder (e.g., ssh-ng://host)";
              example = "ssh-ng://eu.nixbuild.net";
            };
            system = mkOption {
              type = types.str;
              description = "System type (e.g., x86_64-linux)";
              example = "x86_64-linux";
            };
            sshKey = mkOption {
              type = types.str;
              description = "Path to SSH private key for root";
              example = "/root/.ssh/nixbuild";
            };
            maxJobs = mkOption {
              type = types.int;
              default = 1;
              description = "Maximum number of concurrent jobs";
            };
            speedFactor = mkOption {
              type = types.int;
              default = 1;
              description = "Speed factor for job scheduling";
            };
            supportedFeatures = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Supported features (e.g., big-parallel, kvm)";
              example = [
                "big-parallel"
                "benchmark"
              ];
            };
          };
        }
      );
      default = [ ];
      description = "Remote build machines for /etc/nix/machines";
    };

    caches = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            publicKey = mkOption {
              type = types.str;
              description = "Public key for this cache";
              example = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
            };
          };
        }
      );
      default = {
        "https://cache.nixos.org" = {
          publicKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
        };
      };
      description = "Binary caches with their public keys. Keys are URLs, values contain publicKey.";
      example = literalExpression ''
        {
          "https://cache.nixos.org" = {
            publicKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
          };
          "https://my-cache.cachix.org" = {
            publicKey = "my-cache.cachix.org-1:abc123...";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    # Enable etc-managed module for /etc/nix/nix.conf
    my.etc.enable = lib.mkDefault true;

    # Default /etc/nix/nix.conf managed via etc-managed module
    # Users can opt-out with: my.etc.files."nix/nix.conf".enable = false;
    my.etc.files."nix/nix.conf".text = ''
      allowed-users = *
      accept-flake-config = true
      auto-allocate-uids = true
      experimental-features = nix-command flakes auto-allocate-uids ca-derivations
      log-lines = 500
      sandbox = true
      show-trace = true

      trusted-users = root ${userCfg.name}

      auto-optimise-store = true
      keep-going = true

      narinfo-cache-negative-ttl = 0

      connect-timeout = 3
      stalled-download-timeout = 30
      fallback = true
      download-attempts = 2
      builders-use-substitutes = true

      substituters = ${substitutersStr}
      trusted-substituters = ${substitutersStr}
      trusted-public-keys = ${publicKeysStr}
    '';

    # Remote build machines configuration (only if machines are configured)
    # Users can opt-out with: my.etc.files."nix/machines".enable = false;
    my.etc.files."nix/machines" = lib.mkIf (cfg.machines != [ ]) {
      text = lib.concatMapStrings (machine: ''
        ${machine.uri}  ${machine.system}  ${machine.sshKey}  ${toString machine.maxJobs} ${toString machine.speedFactor} ${lib.concatStringsSep "," machine.supportedFeatures}
      '') cfg.machines;
    };

    # Required for nix.settings to work
    nix.package = pkgs.nix;

    # Use home-manager's native nix settings
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "auto-allocate-uids"
        "ca-derivations"
      ];
      inherit substituters;
      trusted-public-keys = publicKeys;
      # Point to static netrc path (synced from sops when available)
      netrc-file = netrcPath;
    };

    # Add include directive for access-tokens (uses static path that always exists)
    nix.extraOptions = ''
      !include ${accessTokensPath}
    '';

    # Ensure secret files exist (empty placeholders or real content)
    # This runs early so nix.conf never fails due to missing files
    home.activation.ensureNixSecrets = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      mkdir -p "$(dirname "${accessTokensPath}")"
      for secret_file in "${accessTokensPath}" "${netrcPath}"; do
        if [ ! -f "$secret_file" ]; then
          touch "$secret_file"
          chmod 600 "$secret_file"
        fi
      done
    '';

    # When sops is enabled, sync decrypted secrets to static paths
    home.activation.syncNixSecrets = lib.mkIf sopsCfg.enable (
      lib.hm.dag.entryAfter [ "sops-nix" ] ''
        sync_secret() {
          local sops_path="$1"
          local static_path="$2"
          local name="$3"
          if [ -f "$sops_path" ]; then
            cat "$sops_path" > "$static_path"
            chmod 600 "$static_path"
          else
            echo "Warning: sops secret '$name' not yet available at $sops_path" >&2
          fi
        }

        sync_secret "${config.sops.secrets.nix_access_tokens.path}" "${accessTokensPath}" "nix_access_tokens"
        sync_secret "${config.sops.secrets.netrc.path}" "${netrcPath}" "netrc"
      ''
    );

    # Define sops secrets when sops is enabled
    sops.secrets = lib.mkIf sopsCfg.enable {
      nix_access_tokens = {
        sopsFile = ../../secrets/secrets.yaml;
      };

      netrc = {
        sopsFile = ../../secrets/secrets.yaml;
      };
    };
  };
}
