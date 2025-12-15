# Terminal profile - Kitty terminal emulator configuration
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.my;
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;

  # kitty-gl wrapper - uses nixgl-nvidia from PATH when nvidia is enabled
  kitty-gl =
    if isX86_64 && cfg.nvidia.enable then
      pkgs.writeShellScriptBin "kitty-gl" ''
        exec nixgl-nvidia ${lib.getExe pkgs.kitty} "$@"
      ''
    else
      pkgs.writeShellScriptBin "kitty-gl" ''
        exec ${lib.getExe pkgs.kitty} "$@"
      '';
in
{
  options.my.terminal = {
    kitty = {
      fontFamily = mkOption {
        type = types.str;
        default = "JetBrains Mono";
        description = "Font family for Kitty terminal";
      };
      fontSize = mkOption {
        type = types.int;
        default = 11;
        description = "Font size for Kitty terminal";
      };
      backgroundOpacity = mkOption {
        type = types.str;
        default = "0.95";
        description = "Background opacity (0.0-1.0)";
      };
      scrollbackLines = mkOption {
        type = types.int;
        default = 10000;
        description = "Number of scrollback lines";
      };
    };
  };

  config = mkIf cfg.profiles.terminal {
    # Kitty terminal configuration
    programs.kitty = {
      enable = true;

      # Fish shell integration
      shellIntegration.enableFishIntegration = true;

      settings = {
        # Shell
        shell = "${lib.getExe pkgs.fish}";

        # Font configuration
        font_family = cfg.terminal.kitty.fontFamily;
        font_size = cfg.terminal.kitty.fontSize;

        # Window appearance
        window_padding_width = 4;
        hide_window_decorations = "yes";
        confirm_os_window_close = 0;

        # Colors
        background_opacity = cfg.terminal.kitty.backgroundOpacity;

        # Scrollback
        scrollback_lines = cfg.terminal.kitty.scrollbackLines;

        # Bell
        enable_audio_bell = false;
        visual_bell_duration = 0;

        # URLs
        url_style = "curly";
        open_url_with = "default";
        detect_urls = true;

        # Cursor
        cursor_shape = "beam";
        cursor_blink_interval = 0;

        # Performance
        repaint_delay = 10;
        input_delay = 3;
        sync_to_monitor = true;

        # Shell integration - enables jumping to prompts, viewing last cmd output, etc.
        shell_integration = "enabled";

        # Tab bar - always show with useful info
        tab_bar_min_tabs = 1;
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";
        tab_title_template = "{index}: {tab.active_wd.rsplit('/', 1)[-1] if tab.active_wd else title}";
        active_tab_title_template = "{index}: {tab.active_wd.rsplit('/', 1)[-1] if tab.active_wd else title}{bell_symbol}{activity_symbol}";
      };

      keybindings = {
        # Clipboard
        "ctrl+shift+c" = "copy_to_clipboard";
        "ctrl+shift+v" = "paste_from_clipboard";

        # Font size
        "ctrl+plus" = "change_font_size all +1.0";
        "ctrl+minus" = "change_font_size all -1.0";
        "ctrl+0" = "change_font_size all 0";

        # Scrolling
        "ctrl+shift+up" = "scroll_line_up";
        "ctrl+shift+down" = "scroll_line_down";
        "ctrl+shift+page_up" = "scroll_page_up";
        "ctrl+shift+page_down" = "scroll_page_down";
        "ctrl+shift+home" = "scroll_home";
        "ctrl+shift+end" = "scroll_end";

        # Tabs - new tabs inherit current working directory
        "ctrl+shift+t" = "new_tab_with_cwd";
        "ctrl+shift+q" = "close_tab";
        "ctrl+shift+right" = "next_tab";
        "ctrl+shift+left" = "previous_tab";

        # Windows/splits - new windows inherit current working directory
        "ctrl+shift+enter" = "new_window_with_cwd";
        "ctrl+shift+w" = "close_window";
        "ctrl+shift+]" = "next_window";
        "ctrl+shift+[" = "previous_window";

        # Hints - select and act on visible text
        "ctrl+shift+p>f" = "kitten hints --type path --program -"; # copy file paths
        "ctrl+shift+p>l" = "kitten hints --type line --program -"; # copy lines
        "ctrl+shift+p>w" = "kitten hints --type word --program -"; # copy words
        "ctrl+shift+p>h" = "kitten hints --type hash --program -"; # copy git hashes
        "ctrl+shift+p>n" = "kitten hints --type linenum"; # open file:line in editor
        "ctrl+shift+p>y" = "kitten hints --type hyperlink"; # open hyperlinks
      };
    };

    # kitty-gl wrapper for nixGL support (uses nixgl-nvidia from nvidia profile)
    home.packages = [ kitty-gl ];
  };
}
