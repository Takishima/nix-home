# Core options used across multiple modules
# User identity, paths, profiles, system commands, and command registry
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.my;

  # Helper function to get system command invocation
  # If path is set, use it directly; otherwise use /usr/bin/env <name>
  getSystemCommand =
    name:
    let
      cmd =
        cfg.systemCommands.${name} or {
          name = name;
          path = null;
        };
    in
    if cmd.path != null then cmd.path else "/usr/bin/env ${cmd.name}";
in
{
  options.my = {
    # NixOS target detection
    isNixOS = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this configuration targets a NixOS system";
    };

    # System commands - configurable paths with NixOS package support
    systemCommands = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              name = mkOption {
                type = types.str;
                default = name;
                description = "Command name for /usr/bin/env lookup";
              };
              path = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Override with explicit path (bypasses /usr/bin/env)";
                example = "/usr/local/bin/nvidia-smi";
              };
              package = mkOption {
                type = types.nullOr types.package;
                default = null;
                description = "Package providing this command (added to home.packages on NixOS)";
              };
              # Note: Commands with explicit paths are checked during activation.
              # Commands using PATH lookup (path = null) are not checked since
              # /usr/bin is not in PATH during activation.
            };
          }
        )
      );
      default = {
        # System binaries that can't come from Nix.
        #
        # Why explicit paths for some commands?
        # During home-manager activation, PATH only contains Nix store paths:
        #   /nix/store/.../bash/bin:/nix/store/.../coreutils/bin:...
        # It does NOT include /usr/bin, so /usr/bin/env <cmd> fails to find
        # system commands. Commands used in activation scripts need explicit paths.
        #
        # Why can't these come from Nix?
        # - nvidia-smi: Provided by the NVIDIA driver, must match kernel module
        # - systemctl: Must communicate with the system's D-Bus/systemd
        # - powerprofilesctl: Must communicate with system power-profiles-daemon
        # - op: System 1Password installation required for biometric authentication
        #
        nvidia-smi.path = "/usr/bin/nvidia-smi";
        systemctl.path = "/usr/bin/systemctl";
        powerprofilesctl = { }; # No explicit path = not checked during activation
        op.path = "/usr/bin/op";
      };
      description = "System commands with configurable paths and NixOS package support";
    };

    # Helper library for use in other modules
    lib = {
      getSystemCommand = mkOption {
        type = types.functionTo types.str;
        default = getSystemCommand;
        description = "Get system command invocation string";
        internal = true;
      };
    };
    # User identity
    user = {
      name = mkOption {
        type = types.str;
        description = "Unix username";
        example = "jsmith";
      };

      fullName = mkOption {
        type = types.str;
        description = "Full name for git commits, etc.";
        example = "Jane Smith";
      };

      email = mkOption {
        type = types.str;
        description = "Primary email address";
        example = "jane.smith@example.com";
      };

      homeDirectory = mkOption {
        type = types.path;
        description = "Home directory path";
        example = "/home/jsmith";
      };

      uid = mkOption {
        type = types.str;
        description = "User ID (required for sops-nix runtime directory paths)";
        example = "1000";
      };
    };

    # Common path configuration
    paths = {
      localBin = mkOption {
        type = types.str;
        default = "$HOME/.local/bin";
        description = "Local binary directory";
      };

      localNgcCli = mkOption {
        type = types.str;
        default = "$HOME/.local/ngc-cli";
        description = "NVIDIA NGC CLI directory";
      };

      cargoHome = mkOption {
        type = types.str;
        default = "$HOME/.cargo";
        description = "Cargo home directory";
      };

      cudaHome = mkOption {
        type = types.str;
        default = "/usr/local/cuda";
        description = "CUDA installation directory";
      };

      onePasswordPath = mkOption {
        type = types.str;
        default = "/opt/1Password";
        description = "1Password installation path";
      };

      gitConfigDir = mkOption {
        type = types.str;
        default = "~/.config/git";
        description = "Git configuration directory (tilde ~ is expanded by git)";
      };

      gitGlobalIgnore = mkOption {
        type = types.str;
        default = "~/.gitignore";
        description = "Global gitignore file (tilde ~ is expanded by git)";
      };

      opConfigDir = mkOption {
        type = types.str;
        default = "$HOME/.config/op";
        description = "1Password CLI configuration directory";
      };

      homeManagerFlakePath = mkOption {
        type = types.str;
        default = "~/code/nix/nix-home";
        description = "Path to home-manager flake repository";
      };
    };

    # Profile toggles (high-level feature bundles)
    profiles = {
      base = mkEnableOption "base profile (essential tools, shell config)" // {
        default = true;
      };
      shell = mkEnableOption "shell profile (bash/fish configuration)" // {
        default = true;
      };
      terminal = mkEnableOption "terminal profile (kitty configuration)" // {
        default = true;
      };
      prompt = mkEnableOption "prompt profile (starship configuration)" // {
        default = true;
      };
      git = mkEnableOption "git profile (git, delta, signing)" // {
        default = true;
      };
      development = mkEnableOption "development profile (dev tools, language servers)";
      plotting = mkEnableOption "plotting tools profile (gnuplot)";
      help = mkEnableOption "help profile (hm-help command)" // {
        default = true;
      };
    };

    # Unified command registry - single source of truth for commands and help text
    commands = {
      # Shell aliases - generates both bash/fish aliases AND help entries
      aliases = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              desc = mkOption {
                type = types.str;
                description = "Short description for help";
              };
              command = mkOption {
                type = types.str;
                description = "Command to execute";
              };
            };
          }
        );
        default = { };
        description = "Shell aliases with descriptions (generates bash/fish aliases and help)";
      };

      # Git aliases - generates both git config AND help entries
      gitAliases = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              desc = mkOption {
                type = types.str;
                description = "Short description for help";
              };
              command = mkOption {
                type = types.str;
                description = "Git alias command";
              };
            };
          }
        );
        default = { };
        description = "Git aliases with descriptions (generates git config and help)";
      };

      # Git scripts - standalone scripts invoked as 'git xxx'
      gitScripts = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              desc = mkOption {
                type = types.str;
                description = "Short description for help";
              };
              package = mkOption {
                type = types.package;
                description = "Package containing the git-xxx script";
              };
            };
          }
        );
        default = { };
        description = "Git scripts with descriptions (installs packages and generates help)";
      };

      # Other scripts - non-git standalone scripts
      scripts = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              desc = mkOption {
                type = types.str;
                description = "Short description for help";
              };
              package = mkOption {
                type = types.package;
                description = "Package containing the script";
              };
              section = mkOption {
                type = types.str;
                default = "Scripts";
                description = "Section name for grouping in help output";
              };
            };
          }
        );
        default = { };
        description = "Scripts with descriptions (installs packages and generates help)";
      };

      # Shell functions - complex functions for bash/fish
      functions = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              desc = mkOption {
                type = types.str;
                description = "Short description for help";
              };
              bash = mkOption {
                type = types.str;
                description = "Bash implementation (function body)";
              };
              fish = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Fish implementation (optional, function body)";
              };
            };
          }
        );
        default = { };
        description = "Shell functions with descriptions (generates bash/fish functions and help)";
      };
    };
  };

  config = lib.mkMerge [
    # On NixOS, automatically install packages for system commands
    (mkIf cfg.isNixOS {
      home.packages = lib.filter (p: p != null) (
        lib.mapAttrsToList (_: cmd: cmd.package) cfg.systemCommands
      );
    })

    # On non-NixOS, check that system commands with checkDuringActivation=true exist
    (mkIf (!cfg.isNixOS) {
      home.activation.checkSystemCommands = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        missing_commands=""

        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: cmd:
            if cmd.path != null then
              # Explicit path - check file exists and is executable
              ''
                if [ ! -x "${cmd.path}" ]; then
                  missing_commands="$missing_commands
                  - ${name}: ${cmd.path} not found or not executable"
                fi
              ''
            else
              # PATH lookup - check command exists
              ''
                if ! command -v "${cmd.name}" &>/dev/null; then
                  missing_commands="$missing_commands
                  - ${name}: '${cmd.name}' not found in PATH"
                fi
              ''
          ) (lib.filterAttrs (_: cmd: cmd.path != null) cfg.systemCommands)
        )}

        if [ -n "$missing_commands" ]; then
          echo ""
          echo "WARNING: Some system commands are not available:"
          echo "$missing_commands"
          echo ""
          echo "Install them or configure paths via my.systemCommands.<name>.path"
          echo ""
        fi
      '';
    })
  ];
}
