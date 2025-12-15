# Prompt profile - Starship prompt configuration
{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.my;
in
{
  options.my.prompt = {
    starship = {
      format = mkOption {
        type = types.str;
        default = "$hostname$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";
        description = "Format string for starship prompt";
      };
      commandTimeout = mkOption {
        type = types.int;
        default = 1000;
        description = "Timeout for command execution in ms";
      };
      showKubernetes = mkEnableOption "kubernetes module in prompt";
      showAws = mkEnableOption "AWS module in prompt";
      showGcloud = mkEnableOption "GCloud module in prompt";
      showAzure = mkEnableOption "Azure module in prompt";
      showPackage = mkEnableOption "package version in prompt";
    };
  };

  config = mkIf cfg.profiles.prompt {
    # Starship prompt
    programs.starship = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;

      settings = {
        format = cfg.prompt.starship.format;
        command_timeout = cfg.prompt.starship.commandTimeout;
        add_newline = false;

        # Only show hostname when connected via SSH
        hostname = {
          ssh_only = true;
          format = "[$ssh_symbol$hostname]($style) ";
          ssh_symbol = "🌐 ";
          style = "bold yellow";
        };

        directory = {
          truncation_length = 3;
          truncate_to_repo = true;
        };

        git_branch = {
          format = "on [$symbol$branch]($style) ";
          symbol = " ";
        };

        git_status = {
          format = "[$all_status$ahead_behind]($style) ";
          conflicted = "=";
          ahead = "⇡$count";
          behind = "⇣$count";
          diverged = "⇕⇡$ahead_count⇣$behind_count";
          untracked = "?$count";
          stashed = "*$count";
          modified = "!$count";
          staged = "+$count";
          deleted = "✘$count";
        };

        nix_shell = {
          format = "via [$symbol$state]($style) ";
          symbol = "❄️ ";
          impure_msg = "impure";
          pure_msg = "pure";
        };

        kubernetes.disabled = !cfg.prompt.starship.showKubernetes;

        cmd_duration = {
          min_time = 2000;
          format = "took [$duration]($style) ";
        };

        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };

        aws.disabled = !cfg.prompt.starship.showAws;
        gcloud.disabled = !cfg.prompt.starship.showGcloud;
        azure.disabled = !cfg.prompt.starship.showAzure;
        package.disabled = !cfg.prompt.starship.showPackage;
      };
    };
  };
}
