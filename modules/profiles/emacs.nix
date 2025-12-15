# Emacs profile - Emacs editor integration and tooling
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.my.emacs;
in
{
  options.my.emacs = {
    enable = mkEnableOption "Emacs integration and tooling";

    enableLspBooster = mkEnableOption "emacs-lsp-booster for faster LSP" // {
      default = true;
    };

    daemonExecPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to emacs executable for daemon systemd service. When set, enables the emacs daemon user service.";
      example = "/snap/bin/emacs";
    };

    daemonEnvironment = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Environment variables for the emacs daemon service";
      example = [
        "LSP_USE_PLISTS=true"
        "LD_LIBRARY_PATH=/usr/local/lib"
      ];
    };
  };

  config = mkIf cfg.enable {
    home.packages = lib.optionals cfg.enableLspBooster [ pkgs.emacs-lsp-booster ];

    # Emacs daemon systemd user service
    systemd.user.services.emacs = lib.mkIf (cfg.daemonExecPath != null) {
      Unit = {
        Description = "Emacs text editor";
        Documentation = "info:emacs man:emacs(1) https://gnu.org/software/emacs/";
      };

      Service = {
        Type = "notify";
        ExecStart = "${cfg.daemonExecPath} --fg-daemon";
        SuccessExitStatus = 15;
        Restart = "always";
      }
      // lib.optionalAttrs (cfg.daemonEnvironment != [ ]) {
        Environment = cfg.daemonEnvironment;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
