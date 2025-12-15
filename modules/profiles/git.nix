# Git profile - Git version control configuration
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.my;

  # Git signing is enabled when a signing key is configured
  # - op-ssh-sign: requires 1Password enabled (local 1Password installation)
  # - ssh-keygen: works with forwarded SSH agent (no local 1Password needed)
  signingEnabled =
    cfg.git.signingKey != null && (cfg.git.sshSigningProgram == "ssh-keygen" || cfg.onePassword.enable);

  # Determine the signing program path
  sshSignProgram =
    if cfg.git.sshSigningProgram == "op-ssh-sign" then
      "${cfg.paths.onePasswordPath}/op-ssh-sign"
    else
      "${pkgs.openssh}/bin/ssh-keygen";

  # Custom git script packages
  git-rebase-main = pkgs.runCommandLocal "git-rebase-main" { } ''
    mkdir -p $out/bin
    substitute ${../../scripts/git-rebase-main.sh} $out/bin/git-rebase-main \
      --replace-fail '@git@' '${lib.getExe pkgs.git}' \
      --replace-fail '@tput@' '${pkgs.ncurses}/bin/tput'
    chmod +x $out/bin/git-rebase-main
  '';

  git-list-outdated = pkgs.runCommandLocal "git-list-outdated" { } ''
    mkdir -p $out/bin
    substitute ${../../scripts/git-list-outdated.sh} $out/bin/git-list-outdated \
      --replace-fail '@git@' '${lib.getExe pkgs.git}' \
      --replace-fail '@grep@' '${lib.getExe pkgs.gnugrep}' \
      --replace-fail '@cut@' '${pkgs.coreutils}/bin/cut' \
      --replace-fail '@sed@' '${lib.getExe pkgs.gnused}' \
      --replace-fail '@sort@' '${pkgs.coreutils}/bin/sort' \
      --replace-fail '@comm@' '${pkgs.coreutils}/bin/comm'
    chmod +x $out/bin/git-list-outdated
  '';

  git-cleanup-branches = pkgs.runCommandLocal "git-cleanup-branches" { } ''
    mkdir -p $out/bin
    substitute ${../../scripts/git-cleanup-branches.sh} $out/bin/git-cleanup-branches \
      --replace-fail '@dialog@' '${lib.getExe pkgs.dialog}' \
      --replace-fail '@git@' '${lib.getExe pkgs.git}' \
      --replace-fail '@tput@' '${pkgs.ncurses}/bin/tput' \
      --replace-fail '@grep@' '${lib.getExe pkgs.gnugrep}' \
      --replace-fail '@cut@' '${pkgs.coreutils}/bin/cut' \
      --replace-fail '@head@' '${pkgs.coreutils}/bin/head'
    chmod +x $out/bin/git-cleanup-branches
  '';

  git-all-rebase-main = pkgs.runCommandLocal "git-all-rebase-main" { } ''
    mkdir -p $out/bin
    substitute ${../../scripts/git-all-rebase-main.sh} $out/bin/git-all-rebase-main \
      --replace-fail '@dialog@' '${lib.getExe pkgs.dialog}' \
      --replace-fail '@git@' '${lib.getExe pkgs.git}' \
      --replace-fail '@tput@' '${pkgs.ncurses}/bin/tput' \
      --replace-fail '@grep@' '${lib.getExe pkgs.gnugrep}' \
      --replace-fail '@cut@' '${pkgs.coreutils}/bin/cut' \
      --replace-fail '@sed@' '${lib.getExe pkgs.gnused}' \
      --replace-fail '@sort@' '${pkgs.coreutils}/bin/sort' \
      --replace-fail '@comm@' '${pkgs.coreutils}/bin/comm'
    chmod +x $out/bin/git-all-rebase-main
  '';
in
{
  options.my.git = {
    signingKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "SSH public key for commit signing";
      example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...";
    };

    sshSigningProgram = mkOption {
      type = types.enum [
        "op-ssh-sign"
        "ssh-keygen"
      ];
      default = "op-ssh-sign";
      description = ''
        Program to use for SSH signing.
        - op-ssh-sign: Use 1Password's signing tool (requires local 1Password)
        - ssh-keygen: Use standard ssh-keygen (works with forwarded SSH agents)
      '';
    };

    enableDelta = mkEnableOption "delta for side-by-side diffs" // {
      default = true;
    };

    enableDifftastic = mkEnableOption "difftastic for structural diff" // {
      default = true;
    };

    enableFsmonitor = mkEnableOption "rs-git-fsmonitor for faster git status";

    mergeDriver = mkOption {
      type = types.enum [
        "mergiraf"
        "default"
      ];
      default = "mergiraf";
      description = "Merge driver to use";
    };

    conflictStyle = mkOption {
      type = types.enum [
        "diff3"
        "merge"
        "zdiff3"
      ];
      default = "diff3";
      description = "Conflict style for git merges";
    };

    setEnvForInternalHosts = mkEnableOption "set git env vars (author/committer) for SSH to *.internal hosts";
  };

  config = mkIf cfg.profiles.git {
    # Register git scripts in unified command registry
    my.commands.gitScripts = {
      rebase-main = {
        desc = "Interactive git branch rebasing onto main";
        package = git-rebase-main;
      };
      all-rebase-main = {
        desc = "Batch rebase multiple branches";
        package = git-all-rebase-main;
      };
      cleanup-branches = {
        desc = "Remove stale local branches";
        package = git-cleanup-branches;
      };
      list-outdated = {
        desc = "List branches out of date with main";
        package = git-list-outdated;
      };
    };

    # Register git aliases in unified command registry
    my.commands.gitAliases = {
      co = {
        desc = "checkout";
        command = "checkout";
      };
      st = {
        desc = "status";
        command = "status";
      };
      d = {
        desc = "diff with patience";
        command = "diff --patience -wb";
      };
      dft = {
        desc = "difftastic diff";
        command = "-c diff.external=difft diff";
      };
      dlog = {
        desc = "difftastic log";
        command = "-c diff.external=difft log -p --ext-diff";
      };
    };

    # Set DELTA_PAGER with explicit less path
    home.sessionVariables.DELTA_PAGER = "${lib.getExe pkgs.less} -R";

    # Install git scripts from unified command registry
    home.packages = lib.mapAttrsToList (name: c: c.package) config.my.commands.gitScripts;

    programs.git = {
      enable = true;

      # Git signing configuration (requires signing key AND 1Password)
      signing = lib.mkIf signingEnabled {
        key = cfg.git.signingKey;
        signByDefault = true;
      };

      ignores = [
        "*~"
        "*.swp"
        ".direnv"
        "result"
        ".envrc"
      ];

      settings = {
        user = {
          name = cfg.user.fullName;
          email = cfg.user.email;
        };

        # Generate git aliases from unified command registry
        alias = lib.mapAttrs (name: c: c.command) config.my.commands.gitAliases;

        init.defaultBranch = "main";

        # GPG/SSH signing (requires signing key AND 1Password for op-ssh-sign)
        gpg = lib.mkIf signingEnabled {
          format = "ssh";
        };

        "gpg \"ssh\"" = lib.mkIf signingEnabled {
          program = sshSignProgram;
          allowedSignersFile = "${cfg.paths.gitConfigDir}/allowed_signers";
        };

        # Core settings
        core = {
          pager = lib.mkIf cfg.git.enableDelta "delta";
          excludesfile = cfg.paths.gitGlobalIgnore;
          untrackedcache = true;
          fsmonitor = lib.mkIf cfg.git.enableFsmonitor (lib.getExe pkgs.rs-git-fsmonitor);
        };

        help.autocorrect = "immediate";

        # Diff
        diff = {
          colorMoved = "default";
          tool = lib.mkIf cfg.git.enableDifftastic "difftastic";
        };

        difftool.prompt = false;
        "difftool \"difftastic\"" = lib.mkIf cfg.git.enableDifftastic {
          cmd = ''difft --ignore-comments --skip-unchanged --graph-limit=10000000 --display=side-by-side-show-both --color=always --syntax-highlight=on "$MERGED" "$LOCAL" "abcdef1" "100644" "$REMOTE" "abcdef2" "100644"'';
        };
        pager.difftool = true;

        # Merge
        merge.conflictStyle = cfg.git.conflictStyle;
        "merge \"mergiraf\"" = lib.mkIf (cfg.git.mergeDriver == "mergiraf") {
          name = "mergiraf";
          driver = "mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
        };

        # Interactive
        interactive.diffFilter = lib.mkIf cfg.git.enableDelta "delta --color-only --features=interactive";

        # Delta configuration
        delta = lib.mkIf cfg.git.enableDelta {
          side-by-side = true;
          features = "decorations line-numbers";
          map-styles = "bold purple => syntax magenta, bold cyan => syntax blue";
          pager = "${lib.getExe pkgs.less} -R";
        };

        "delta \"magit-delta\"" = lib.mkIf cfg.git.enableDelta {
          line-numbers = false;
        };

        "delta \"interactive\"" = lib.mkIf cfg.git.enableDelta {
          keep-plus-minus-markers = false;
        };

        "delta \"decorations\"" = lib.mkIf cfg.git.enableDelta {
          commit-decoration-style = "blue ol";
          commit-style = "raw";
          hunk-header-decoration-style = "blue box";
          hunk-header-file-style = "red";
          hunk-header-line-number-style = "#067a00";
          hunk-header-style = "file line-number syntax";
        };

        # Fetch
        fetch = {
          parallel = 0;
          prune = true;
          pruneTags = true;
          writeCommitGraph = true;
        };

        # Rerere
        rerere = {
          enabled = true;
          autoUpdate = true;
        };

        # UI
        color.ui = "auto";
        column.ui = "auto";
        branch.sort = "-committerdate";
        rebase.updateRefs = true;

        # GitHub credentials
        "credential \"https://github.com\"" = {
          helper = [
            ""
            "!/usr/bin/gh auth git-credential"
          ];
        };
      };
    };

    # Delta for nice diffs
    programs.delta = lib.mkIf cfg.git.enableDelta {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
      };
    };

    # Set git author/committer env vars for internal hosts
    # This ensures commits made over SSH to *.internal hosts use the correct identity
    programs.ssh.matchBlocks."*.internal" = lib.mkIf cfg.git.setEnvForInternalHosts {
      setEnv = {
        GIT_AUTHOR_NAME = cfg.user.fullName;
        GIT_AUTHOR_EMAIL = cfg.user.email;
        GIT_COMMITTER_NAME = cfg.user.fullName;
        GIT_COMMITTER_EMAIL = cfg.user.email;
      };
    };
  };
}
