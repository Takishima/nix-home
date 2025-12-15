# 1Password integration profile - SSH agent, git signing
# Features are conditional on 1Password being available at runtime
{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.my;
  opCfg = cfg.onePassword;

  # Expand ~ to $HOME for shell scripts (~ doesn't expand in double quotes)
  # Fish doesn't support ${VAR} syntax, only $VAR
  agentSocketBash = builtins.replaceStrings [ "~" ] [ "\${HOME}" ] opCfg.agentSocket;
  agentSocketFish = builtins.replaceStrings [ "~" ] [ "$HOME" ] opCfg.agentSocket;
in
{
  options.my.onePassword = {
    enable = mkEnableOption "1Password integration (SSH agent, git signing)";

    agentSocket = mkOption {
      type = types.str;
      default = "~/.1password/agent.sock";
      description = "Path to 1Password SSH agent socket";
    };
    # Note: CLI path is now configured via my.systemCommands.op.path
  };

  config = mkIf opCfg.enable {
    # SSH agent socket via 1Password (with runtime check)
    # Don't set in sessionVariables as it runs too early
    programs.bash.initExtra = lib.mkAfter ''
      # 1Password SSH agent (only if socket exists)
      if [ -S "${agentSocketBash}" ]; then
          export SSH_AUTH_SOCK="${agentSocketBash}"
      fi

      # 1Password CLI plugins (only if available)
      if [ -f "${cfg.user.homeDirectory}/.config/op/plugins.sh" ]; then
          source "${cfg.user.homeDirectory}/.config/op/plugins.sh"
      fi
    '';

    programs.fish.interactiveShellInit = lib.mkAfter ''
      # 1Password SSH agent (only if socket exists)
      if test -S "${agentSocketFish}"
          set -gx SSH_AUTH_SOCK "${agentSocketFish}"
      end

      # 1Password CLI plugins (fish version)
      if test -f "${cfg.user.homeDirectory}/.config/op/plugins.sh"
          source "${cfg.user.homeDirectory}/.config/op/plugins.sh"
      end
    '';

    # SSH global defaults - identity agent for 1Password
    # This tells SSH to use 1Password for key management
    programs.ssh.matchBlocks."*" = {
      identityAgent = opCfg.agentSocket;
      extraOptions.AddKeysToAgent = "yes";
    };

    # Git signing is handled in modules/profiles/git.nix
  };
}
