# Declarative /etc file management for non-NixOS systems
# Stages files to ~/.config/etc-managed/ and provides hm-sys command to apply with sudo
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.etc;

  # Import scripts
  scripts = import ./scripts.nix { inherit config pkgs; };

  # File entry submodule
  fileType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to manage this file. Set to false to opt-out.";
      };
      text = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "File contents as text";
      };
      source = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Source file path (alternative to text)";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "0644";
        description = "File permissions";
      };
    };
  };

  # Filter to only enabled files
  enabledFiles = lib.filterAttrs (_: fileEntry: fileEntry.enable) cfg.files;

  # Generate manifest JSON with file metadata (only enabled files)
  manifestJson = builtins.toJSON (
    lib.mapAttrsToList (
      etcPath: fileEntry:
      let
        content = if fileEntry.text != null then fileEntry.text else builtins.readFile fileEntry.source;
      in
      {
        path = etcPath;
        hash = builtins.hashString "sha256" content;
        mode = fileEntry.mode;
      }
    ) enabledFiles
  );

in
{
  options.my.etc = {
    enable = lib.mkEnableOption "declarative /etc file management";

    stagingDir = lib.mkOption {
      type = lib.types.str;
      default = ".config/etc-managed";
      description = "Staging directory relative to home (where files are staged)";
    };

    promptMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true and HM_ETC_PROMPT=1, activation will auto-run hm-sys apply";
    };

    notifyOnSync = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable systemd path watcher to send desktop notification when sync needed";
    };

    files = lib.mkOption {
      type = lib.types.attrsOf fileType;
      default = { };
      description = ''
        Attribute set of /etc files to manage.
        Keys are paths relative to /etc (e.g., "sysctl.d/10-ros2.conf").
        Values define content via text or source.
      '';
      example = lib.literalExpression ''
        {
          "sysctl.d/10-ros2.conf" = {
            text = '''
              net.core.rmem_max = 20971520
              net.core.wmem_max = 20971520
            ''';
          };
          "modprobe.d/nvidia-pm.conf" = {
            text = "options nvidia NVreg_PreserveVideoMemoryAllocations=0";
            mode = "0644";
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Stage files to ~/.config/etc-managed/files/
    home.file =
      lib.mapAttrs' (
        etcPath: fileEntry:
        lib.nameValuePair "${cfg.stagingDir}/files/${etcPath}" (
          if fileEntry.text != null then { text = fileEntry.text; } else { source = fileEntry.source; }
        )
      ) enabledFiles
      // {
        # Generate manifest file with metadata
        "${cfg.stagingDir}/.manifest" = {
          text = manifestJson;
        };
      };

    # Activation hook to check /etc sync status
    home.activation.checkEtcManaged = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      # Skip if HM_ETC_SKIP=1
      if [ "''${HM_ETC_SKIP:-0}" = "1" ]; then
        exit 0
      fi

      STAGING_DIR="${config.home.homeDirectory}/${cfg.stagingDir}"
      MANIFEST_FILE="$STAGING_DIR/.manifest"
      ETC_ISSUES=""

      # Check if manifest exists (may not on first run before files are written)
      if [ -f "$MANIFEST_FILE" ]; then
        # Read manifest and check each file
        while IFS= read -r entry; do
          etc_path=$(echo "$entry" | ${pkgs.jq}/bin/jq -r '.path')
          staged_file="$STAGING_DIR/files/$etc_path"
          etc_file="/etc/$etc_path"

          if [ ! -f "$etc_file" ]; then
            ETC_ISSUES="$ETC_ISSUES
        - Missing: /etc/$etc_path"
          elif [ -f "$staged_file" ]; then
            staged_hash=$(${pkgs.coreutils}/bin/sha256sum "$staged_file" 2>/dev/null | cut -d' ' -f1 || echo "")
            current_hash=$(${pkgs.coreutils}/bin/sha256sum "$etc_file" 2>/dev/null | cut -d' ' -f1 || echo "")

            if [ -n "$staged_hash" ] && [ -n "$current_hash" ] && [ "$current_hash" != "$staged_hash" ]; then
              ETC_ISSUES="$ETC_ISSUES
        - Out of sync: /etc/$etc_path"
            fi
          fi
        done < <(${pkgs.jq}/bin/jq -c '.[]' "$MANIFEST_FILE" 2>/dev/null || true)
      fi

      if [ -n "$ETC_ISSUES" ]; then
        echo ""
        echo "WARNING: System files are out of sync with home-manager configuration!"
        echo ""
        echo "Issues:$ETC_ISSUES"
        echo ""
        echo "Run 'hm-sys status' for overview"
        echo "Run 'hm-sys diff' to see changes"
        echo "Run 'hm-sys apply' to apply changes (requires sudo)"
        echo ""

        ${lib.optionalString cfg.promptMode ''
          # Optional: Auto-apply if HM_ETC_PROMPT=1
          if [ "''${HM_ETC_PROMPT:-0}" = "1" ]; then
            echo "HM_ETC_PROMPT is set. Applying system file changes now..."
            ${scripts.hm-sys}/bin/hm-sys apply
          fi
        ''}
      fi
    '';

    # Register command in the command registry for help system
    my.commands.scripts.hm-sys = {
      desc = "Manage system files staged by home-manager (status|diff|apply)";
      package = scripts.hm-sys;
      section = "Managed System Files";
    };

    # Install the command package
    home.packages = [
      scripts.hm-sys
    ];

    # Optional systemd notification for when files need sync
    systemd.user.paths.etc-managed-watch = lib.mkIf cfg.notifyOnSync {
      Unit = {
        Description = "Watch for home-manager etc-managed changes";
      };
      Path = {
        PathChanged = "${config.home.homeDirectory}/${cfg.stagingDir}/.manifest";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    systemd.user.services.etc-managed-notify = lib.mkIf cfg.notifyOnSync {
      Unit = {
        Description = "Notify when system files need sync";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.libnotify}/bin/notify-send --app-name='Home Manager' 'hm-sys' 'System files may need syncing. Run hm-sys status to check.'";
      };
    };
  };
}
