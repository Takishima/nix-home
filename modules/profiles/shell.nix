# Shell profile - bash and fish shell configuration
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.my;
  getCmd = cfg.lib.getSystemCommand;

  # Detect architecture and append suffix for aarch64
  configName =
    if pkgs.stdenv.hostPlatform.isAarch64 then "${cfg.user.name}-aarch64" else cfg.user.name;

  # Power management utility (uses system powerprofilesctl for D-Bus compatibility)
  hm-power = pkgs.runCommandLocal "hm-power" { } ''
    mkdir -p $out/bin
    substitute ${../../scripts/hm-power.sh} $out/bin/hm-power \
      --replace-fail '@powerprofilesctl@' '${getCmd "powerprofilesctl"}' \
      --replace-fail '@cpupower@' '${pkgs.linuxPackages.cpupower}/bin/cpupower'
    chmod +x $out/bin/hm-power
  '';
in
{
  options.my.shell = {
    enableBash = mkEnableOption "bash shell" // {
      default = true;
    };
    enableFish = mkEnableOption "fish shell" // {
      default = true;
    };
  };

  config = mkIf cfg.profiles.shell {
    # Register shell aliases in unified command registry
    my.commands.aliases = {
      # Modern CLI replacements
      l = {
        desc = "eza with icons and long format";
        command = "eza --long --icons --follow-symlinks";
      };

      # Nix / Home Manager (architecture-aware)
      hms = {
        desc = "home-manager switch";
        command = "home-manager switch --flake ${cfg.paths.homeManagerFlakePath}#${configName}";
      };
      hmb = {
        desc = "home-manager build";
        command = "home-manager build --flake ${cfg.paths.homeManagerFlakePath}#${configName}";
      };
      hme = {
        desc = "Edit home-manager config";
        command = "$EDITOR ${cfg.paths.homeManagerFlakePath}";
      };
      clean-nix = {
        desc = "Garbage collect nix store";
        command = "nix store gc && nix-collect-garbage --delete-older-than 7d";
      };
      nix-show-gc = {
        desc = "Show nix garbage collection roots";
        command = ''nix-store --gc --print-roots | egrep -v "^(/nix/var|/run/\\w+-system|\\{memory|/proc|\\{temp:[0-9]+)"'';
      };

      # Direnv
      dr = {
        desc = "Direnv reload";
        command = "direnv reload && nix-direnv-reload";
      };

      # Kubernetes
      k = {
        desc = "kubectl shorthand";
        command = "kubectl";
      };

      # Misc
      kill1 = {
        desc = "Kill first background job";
        command = "kill -9 %1";
      };
      emacs = {
        desc = "Emacs client (terminal)";
        command = "/snap/bin/emacsclient -nw";
      };
      highlight = {
        desc = "Syntax highlighting";
        command = "${lib.getExe pkgs.highlight} -s candy";
      };
      less = {
        desc = "Less with options";
        command = "less -m -N -g -i -J --line-numbers --underline-special";
      };
      pcs = {
        desc = "Build pre-commit config";
        command = "nix build --impure .#.devShells.$(uname -p)-linux.default.config.git-hooks.configFile --out-link .pre-commit-config.yaml";
      };
      apt-all-update = {
        desc = "Update all package managers";
        command = "sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo snap refresh && cargo install-update --all && nix profile upgrade --impure --all";
      };
    };

    # Shell functions for home-manager
    my.commands.functions = {
      hm-update = {
        desc = "Pull home-manager repo and switch";
        bash = ''
          local hm_path="${cfg.paths.homeManagerFlakePath}"
          hm_path="''${hm_path/#\~/$HOME}"

          # Check if repo is clean
          if ! "${lib.getExe pkgs.git}" -C "$hm_path" diff --quiet HEAD 2>/dev/null; then
              echo "Error: home-manager repo has uncommitted changes" >&2
              "${lib.getExe pkgs.git}" -C "$hm_path" status --short
              return 1
          fi

          # Pull latest changes (fast-forward only)
          echo "Pulling latest changes..."
          if ! "${lib.getExe pkgs.git}" -C "$hm_path" pull --ff-only; then
              echo "Error: git pull failed (branches may have diverged)" >&2
              return 1
          fi

          # Run home-manager switch
          echo "Running home-manager switch..."
          home-manager switch --flake "$hm_path#${configName}"
        '';
        fish = ''
          set -l hm_path (string replace '~' "$HOME" "${cfg.paths.homeManagerFlakePath}")

          # Check if repo is clean
          if not "${lib.getExe pkgs.git}" -C "$hm_path" diff --quiet HEAD 2>/dev/null
              echo "Error: home-manager repo has uncommitted changes" >&2
              "${lib.getExe pkgs.git}" -C "$hm_path" status --short
              return 1
          end

          # Pull latest changes (fast-forward only)
          echo "Pulling latest changes..."
          if not "${lib.getExe pkgs.git}" -C "$hm_path" pull --ff-only
              echo "Error: git pull failed (branches may have diverged)" >&2
              return 1
          end

          # Run home-manager switch
          echo "Running home-manager switch..."
          home-manager switch --flake "$hm_path#${configName}"
        '';
      };
      hm-rollback = {
        desc = "Rollback to a previous home-manager generation";
        bash = ''
          local profile_dir="$HOME/.local/state/nix/profiles"
          local current
          current=$(readlink "$profile_dir/home-manager")

          # List generations and pick one with fzf
          local selection
          selection=$(home-manager generations | "${lib.getExe pkgs.fzf}" --height=40% --reverse \
              --header="Current: $current" \
              --preview='echo {}' \
              --preview-window=up:1)

          [ -z "$selection" ] && return 0

          # Extract generation path from selection (format: "2024-01-01 12:00 : id 123 -> /nix/store/...")
          local gen_path
          gen_path=$(echo "$selection" | "${lib.getExe pkgs.gawk}" -F' -> ' '{print $2}')

          if [ -z "$gen_path" ] || [ ! -d "$gen_path" ]; then
              echo "Error: Could not find generation path" >&2
              return 1
          fi

          echo "Activating: $gen_path"
          "$gen_path/activate"
        '';
        fish = ''
          set -l profile_dir "$HOME/.local/state/nix/profiles"
          set -l current (readlink "$profile_dir/home-manager")

          # List generations and pick one with fzf
          set -l selection (home-manager generations | "${lib.getExe pkgs.fzf}" --height=40% --reverse \
              --header="Current: $current" \
              --preview='echo {}' \
              --preview-window=up:1)

          test -z "$selection" && return 0

          # Extract generation path from selection
          set -l gen_path (echo "$selection" | "${lib.getExe pkgs.gawk}" -F' -> ' '{print $2}')

          if test -z "$gen_path" -o ! -d "$gen_path"
              echo "Error: Could not find generation path" >&2
              return 1
          end

          echo "Activating: $gen_path"
          "$gen_path/activate"
        '';
      };
      hm-diff = {
        desc = "Show derivation diff between current and new home-manager build";
        bash = ''
          local hm_path="${cfg.paths.homeManagerFlakePath}"
          hm_path="''${hm_path/#\~/$HOME}"
          local profile_dir="$HOME/.local/state/nix/profiles"
          local current
          current=$(readlink -f "$profile_dir/home-manager")

          echo "Building new configuration..."
          if ! home-manager build --flake "$hm_path#${configName}"; then
              echo "Error: Build failed" >&2
              return 1
          fi

          local new_build
          new_build=$(readlink -f "$hm_path/result")

          if [ -z "$new_build" ] || [ ! -d "$new_build" ]; then
              echo "Error: Could not find build result" >&2
              return 1
          fi

          # Get derivations from store paths
          local current_drv new_drv
          current_drv=$(nix-store -qd "$current")
          new_drv=$(nix-store -qd "$new_build")

          echo ""
          "${lib.getExe pkgs.nix-diff}" "$current_drv" "$new_drv" --color always
        '';
        fish = ''
          set -l hm_path (string replace '~' "$HOME" "${cfg.paths.homeManagerFlakePath}")
          set -l profile_dir "$HOME/.local/state/nix/profiles"
          set -l current (readlink -f "$profile_dir/home-manager")

          echo "Building new configuration..."
          if not home-manager build --flake "$hm_path#${configName}"
              echo "Error: Build failed" >&2
              return 1
          end

          set -l new_build (readlink -f "$hm_path/result")

          if test -z "$new_build" -o ! -d "$new_build"
              echo "Error: Could not find build result" >&2
              return 1
          end

          # Get derivations from store paths
          set -l current_drv (nix-store -qd "$current")
          set -l new_drv (nix-store -qd "$new_build")

          echo ""
          "${lib.getExe pkgs.nix-diff}" "$current_drv" "$new_drv" --color always
        '';
      };
      hm-push = lib.mkIf (cfg.nix.cachixCache != null) {
        desc = "Push current home-manager generation to cachix";
        bash = ''
          local cache="${cfg.nix.cachixCache}"
          local current
          current=$(readlink -f "$HOME/.local/state/nix/profiles/home-manager")

          if [ -z "$current" ] || [ ! -d "$current" ]; then
              echo "Error: Could not find current home-manager generation" >&2
              return 1
          fi

          echo "Pushing current generation to cachix cache: $cache"
          echo "  $current"
          cachix push "$cache" "$current"
        '';
        fish = ''
          set -l cache "${cfg.nix.cachixCache}"
          set -l current (readlink -f "$HOME/.local/state/nix/profiles/home-manager")

          if test -z "$current" -o ! -d "$current"
              echo "Error: Could not find current home-manager generation" >&2
              return 1
          end

          echo "Pushing current generation to cachix cache: $cache"
          echo "  $current"
          cachix push "$cache" "$current"
        '';
      };
    };

    # Power management utility
    home.packages = [
      hm-power
    ];

    # Bash shell configuration
    programs.bash = lib.mkIf cfg.shell.enableBash {
      enable = true;

      # Shell options
      shellOptions = [
        "checkwinsize" # Update LINES/COLUMNS after each command
      ];

      sessionVariables = {
        # Less with syntax highlighting
        LESSOPEN = ''| $(which highlight) %s --out-format xterm256 -l --force -s candy --no-trailing-nl'';
        LESS = "-R"; # -R enables color, removed --mouse to allow text selection
        # Node
        NODE_OPTIONS = "--max-old-space-size=8192";
      };

      profileExtra = ''
        # Helper function for printing path variables
        print_path_var() {
            while [ -n "$1" ]; do
                echo "''${1}"
                echo "''${!1}" | tr : '\n'
                shift
            done
        }
      '';

      # Generate bash aliases from unified command registry
      shellAliases = lib.mapAttrs (name: c: c.command) config.my.commands.aliases;

      initExtra = ''
        # Set terminal title for non-Kitty terminals (Guake, etc.)
        if [ "$TERM" != "xterm-kitty" ]; then
            __set_terminal_title() {
                local title repo branch
                if git rev-parse --is-inside-work-tree &>/dev/null; then
                    local git_dir
                    git_dir=$(git rev-parse --show-superproject-working-tree 2>/dev/null)
                    [ -z "$git_dir" ] && git_dir=$(git rev-parse --show-toplevel 2>/dev/null)
                    repo=$(basename "$git_dir")
                    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
                    title="$repo: $branch"
                else
                    local path="$PWD"
                    [[ "$path" == "$HOME"* ]] && path="~''${path#$HOME}"
                    title="$USER@$HOSTNAME: $path"
                fi
                echo -ne "\033]0;$title\007"
            }
            PROMPT_COMMAND="__set_terminal_title;$PROMPT_COMMAND"
        fi

        # Color support for ls/grep
        if test -r ~/.dircolors; then
            eval "$(${pkgs.coreutils}/bin/dircolors -b ~/.dircolors)"
        else
            eval "$(${pkgs.coreutils}/bin/dircolors -b)"
        fi
        alias ls='ls --color=auto'
        alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
        alias egrep='egrep --color=auto'

        # Non-nix-shell paths (CUDA, local binaries)
        if [ -z "$IN_NIX_SHELL" ]; then
            if [ -f "${cfg.paths.cargoHome}/env" ]; then
                . "${cfg.paths.cargoHome}/env"
            fi
            export PATH="${cfg.paths.localBin}:''${PATH}:${cfg.paths.localNgcCli}:${cfg.paths.onePasswordPath}"
            export CUDA_HOME=${cfg.paths.cudaHome}
            export PATH="$CUDA_HOME/bin:''${PATH:+:''${PATH}}"
            export LD_LIBRARY_PATH="$CUDA_HOME/lib64:''${LD_LIBRARY_PATH:+:''${LD_LIBRARY_PATH}}"
        fi

        # Git worktree switcher
        if command -v wt >&/dev/null; then
            eval "$(command wt init bash)"
        fi

        # Kubectl completion
        if command -v kubectl >&/dev/null; then
            source <(kubectl completion bash)
            complete -o default -F __start_kubectl k
        fi
      '';
    };

    # Fish shell configuration
    programs.fish = lib.mkIf cfg.shell.enableFish {
      enable = true;

      # Generate fish abbreviations from unified command registry
      shellAbbrs = lib.mapAttrs (name: c: c.command) config.my.commands.aliases;

      shellInit = ''
        # Less with syntax highlighting
        set -gx LESSOPEN "| (which highlight) %s --out-format xterm256 -l --force -s candy --no-trailing-nl"
        set -gx LESS " -R"

        # Node
        set -gx NODE_OPTIONS "--max-old-space-size=8192"
      '';

      interactiveShellInit = ''
        # Terminal title: repo name in git repo, otherwise user@host: path
        function fish_title
            set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
            if test -n "$git_root"
                basename $git_root
            else
                set -l path (string replace $HOME "~" $PWD)
                echo "$USER@$hostname: $path"
            end
        end

        # Non-nix-shell paths
        if not set -q IN_NIX_SHELL
            fish_add_path -g ${cfg.paths.localBin}
            fish_add_path -g ${cfg.paths.localNgcCli}
            fish_add_path -g ${cfg.paths.onePasswordPath}
            fish_add_path -g ${cfg.paths.cargoHome}/bin

            set -gx CUDA_HOME ${cfg.paths.cudaHome}
            fish_add_path -g $CUDA_HOME/bin
            set -gx LD_LIBRARY_PATH "$CUDA_HOME/lib64:$LD_LIBRARY_PATH"
        end

        # Kubectl completion
        if command -v kubectl >/dev/null
            kubectl completion fish | source
        end
      '';
    };
  };
}
