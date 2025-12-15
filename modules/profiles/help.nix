# Help profile - generates hm-help command from unified command registry
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my;
  cmdsCfg = cfg.commands;

  # Sort commands alphabetically by name
  sortByName = list: builtins.sort (a: b: a.name < b.name) list;

  # Build help entries from my.commands.*
  aliasEntries = lib.mapAttrsToList (name: c: {
    inherit name;
    desc = c.desc;
  }) cmdsCfg.aliases;

  scriptEntries = lib.mapAttrsToList (name: c: {
    inherit name;
    desc = c.desc;
  }) cmdsCfg.scripts;

  functionEntries = lib.mapAttrsToList (name: c: {
    inherit name;
    desc = c.desc;
  }) cmdsCfg.functions;

  # Git entries combine gitAliases and gitScripts, displayed as "git <name>"
  gitAliasEntries = lib.mapAttrsToList (name: c: {
    name = "git ${name}";
    desc = "${c.desc} (alias)";
  }) cmdsCfg.gitAliases;

  gitScriptEntries = lib.mapAttrsToList (name: c: {
    name = "git ${name}";
    desc = c.desc;
  }) cmdsCfg.gitScripts;

  gitEntries = gitAliasEntries ++ gitScriptEntries;

  # Format a list of entries as aligned lines
  formatEntries =
    entries:
    let
      sorted = sortByName entries;
      maxLen = builtins.foldl' (
        acc: e: if builtins.stringLength e.name > acc then builtins.stringLength e.name else acc
      ) 0 sorted;
      pad = n: s: s + lib.strings.replicate (n - builtins.stringLength s) " ";
    in
    lib.concatMapStringsSep "\n" (e: "  ${pad maxLen e.name}  ${e.desc}") sorted;

  # Generate the help script content
  helpScript = pkgs.writeShellScriptBin "hm-help" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Colors
    BOLD='\033[1m'
    CYAN='\033[36m'
    YELLOW='\033[33m'
    RESET='\033[0m'

    show_git=false
    show_all=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
      case $1 in
        --git)
          show_git=true
          shift
          ;;
        --all)
          show_all=true
          shift
          ;;
        -h|--help)
          echo "Usage: hm-help [--all] [--git]"
          echo ""
          echo "Options:"
          echo "  --all   Show all commands including git"
          echo "  --git   Show only git commands"
          exit 0
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done

    echo -e "''${BOLD}Home Manager Custom Commands''${RESET}"
    echo "============================"
    echo ""

    # If --git only, show git section and exit
    if $show_git && ! $show_all; then
      ${
        if gitEntries != [ ] then
          ''
            echo -e "''${CYAN}GIT''${RESET}"
            cat <<'GITEOF'
            ${formatEntries gitEntries}
            GITEOF
          ''
        else
          ''echo "No git commands registered."''
      }
      exit 0
    fi

    # Show default sections (scripts, aliases, functions)
    ${
      if scriptEntries != [ ] then
        ''
          echo -e "''${CYAN}SCRIPTS''${RESET}"
          cat <<'SCRIPTSEOF'
          ${formatEntries scriptEntries}
          SCRIPTSEOF
          echo ""
        ''
      else
        ""
    }

    ${
      if aliasEntries != [ ] then
        ''
          echo -e "''${CYAN}ALIASES''${RESET}"
          cat <<'ALIASESEOF'
          ${formatEntries aliasEntries}
          ALIASESEOF
          echo ""
        ''
      else
        ""
    }

    ${
      if functionEntries != [ ] then
        ''
          echo -e "''${CYAN}FUNCTIONS''${RESET}"
          cat <<'FUNCTIONSEOF'
          ${formatEntries functionEntries}
          FUNCTIONSEOF
          echo ""
        ''
      else
        ""
    }

    # Show git section if --all
    if $show_all; then
      ${
        if gitEntries != [ ] then
          ''
            echo -e "''${CYAN}GIT''${RESET}"
            cat <<'GITALLEOF'
            ${formatEntries gitEntries}
            GITALLEOF
            echo ""
          ''
        else
          ""
      }
    else
      ${
        if gitEntries != [ ] then
          ''echo -e "''${YELLOW}Use 'hm-help --all' to include git commands''${RESET}"''
        else
          ""
      }
    fi
  '';
in
{
  config = lib.mkIf cfg.profiles.help {
    home.packages = [ helpScript ];
  };
}
