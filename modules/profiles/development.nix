# Development profile - git, dev tools, languages, nix tooling
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.my;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  config = lib.mkIf cfg.profiles.development {
    # Development tools
    home.packages =
      (with pkgs; [
        # Environment management
        nix-direnv

        # Git tools
        git-worktree-switcher
        mergiraf # git merge driver

        # Build/patch tools
        patchelf
        pre-commit

        # MCP servers
        github-mcp-server

        # Go
        go

        # Tree-sitter CLI and grammars
        tree-sitter

        # Language servers
        bash-language-server
        clang-tools # clangd, clang-format, etc.
        gopls # Go language server
        neocmakelsp # CMake LSP
        pyright # Python type checker/LSP
        python3Packages.python-lsp-server # Python LSP
        taplo # TOML LSP

        # Python tools
        ruff # Python linter/formatter
        ty # Python type checker

        # Spell checking
        typos # Source code spell checker
        typos-lsp # Typos LSP

        # Build tools
        cmake-format

        # Nix linting and formatting
        deadnix # Find dead Nix code
        statix # Nix linter
        nixfmt-rfc-style # Nix formatter

        # Nix analysis and debugging
        nix-diff # Compare Nix derivations
        nix-du # Disk usage analyzer
        nix-tree # Visualize Nix derivations
        nvd # Nix version diff (compare generations)
        dix # Nix derivation inspector
        nix-output-monitor # Better nix build output

        # Cloud and infrastructure tools
        azure-cli
        kubectl
        kubectx # kubectl context/namespace switcher
        k9s # Kubernetes TUI
        terraform
        opentofu # Open source Terraform fork
        terraform-lsp
        terraform-mcp-server
        tflint # Terraform linter
        sops # Secrets management
        netavark # Container networking

        # Packages from overlays
        mcp-pypi
      ])
      ++ [
        # External flake packages
        inputs.cachix.packages.${system}.default
        inputs.devenv.packages.${system}.default
        inputs.claude-code-nix.packages.${system}.default
        inputs.nix-ai-tools.packages.${system}.opencode
        inputs.nix-index.packages.${system}.default
        inputs.nix-update.packages.${system}.default
        inputs.nil.packages.${system}.default # Nix LSP
        inputs.rime.packages.${system}.default # Nix MCP server
      ];

    # Git configuration moved to modules/profiles/git.nix

    # SSH base configuration (without 1Password)
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks = {
        # Global defaults
        "*" = {
          extraOptions = {
            AddKeysToAgent = "yes";
          };
        };

        # Password-only hosts pattern
        "*-pass" = {
          forwardAgent = false;
          extraOptions = {
            PreferredAuthentications = "password";
            PubkeyAuthentication = "no";
            PasswordAuthentication = "yes";
          };
        };

        # Git hosts
        "github.com" = {
          hostname = "github.com";
          user = "git";
          identityFile = "~/.ssh/github_personal.pub";
          identitiesOnly = true;
        };

        # Remote builders (only if nixbuildSshKey is configured)
        "eu.nixbuild.net" = lib.mkIf (cfg.nix.nixbuildSshKey != null) {
          hostname = "eu.nixbuild.net";
          user = "root";
          identityFile = cfg.nix.nixbuildSshKey;
          identitiesOnly = true;
          extraOptions = {
            PubkeyAcceptedKeyTypes = "ssh-ed25519";
            ServerAliveInterval = "60";
            IPQoS = "throughput";
          };
        };
      };
    };
  };
}
