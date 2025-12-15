# GNOME desktop integration - custom keybindings, kitty-quake, emacs-multiscreen
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.gnome;

  # Quake-style dropdown for Kitty
  kitty-quake = pkgs.writeShellScriptBin "kitty-quake" ''
    # Get the active window class
    ACTIVE_WINDOW=$(${lib.getExe pkgs.xdotool} getactivewindow getwindowclassname 2>/dev/null)

    # Check if kitty-quake is already running
    KITTY_WINDOW=$(${lib.getExe pkgs.xdotool} search --class "kitty-quake" 2>/dev/null | head -1)

    if [ "$ACTIVE_WINDOW" = "kitty-quake" ]; then
      # Kitty has focus, save current window and hide kitty
      ${lib.getExe pkgs.xdotool} getactivewindow > ~/.lastfocusedwindow 2>/dev/null || true
      ${lib.getExe pkgs.xdotool} search --class "kitty-quake" windowunmap 2>/dev/null
    elif [ -n "$KITTY_WINDOW" ]; then
      # Kitty exists but doesn't have focus, save current window and show kitty
      ${lib.getExe pkgs.xdotool} getactivewindow > ~/.lastfocusedwindow 2>/dev/null || true
      ${lib.getExe pkgs.xdotool} search --class "kitty-quake" windowmap windowactivate 2>/dev/null
    else
      # Kitty doesn't exist, create it
      ${lib.getExe pkgs.xdotool} getactivewindow > ~/.lastfocusedwindow 2>/dev/null || true

      # Hardcoded laptop display dimensions (DP-4: 1920x1200+0+0)
      WIDTH=1920
      HEIGHT=1200
      X_OFFSET=0
      Y_OFFSET=0

      # Calculate dimensions: full width, 50% height, anchored to top
      QUAKE_HEIGHT=$((HEIGHT / 2))

      # Launch kitty with nixGL wrapper for NVIDIA support, using fish shell
      kitty-gl \
        --class=kitty-quake \
        -o remember_window_size=no \
        -o initial_window_width=$WIDTH \
        -o initial_window_height=$QUAKE_HEIGHT \
        -o placement_strategy=top-left \
        ${lib.getExe pkgs.fish} &

      # Wait for window to appear
      sleep 0.5

      # Get the new kitty window - retry a few times
      for i in {1..10}; do
        KITTY_WINDOW=$(${lib.getExe pkgs.xdotool} search --class "kitty-quake" 2>/dev/null | head -1)
        if [ -n "$KITTY_WINDOW" ]; then
          break
        fi
        sleep 0.1
      done

      if [ -n "$KITTY_WINDOW" ]; then
        # Unmap the window first to prevent flashing
        ${lib.getExe pkgs.xdotool} windowunmap "$KITTY_WINDOW"

        # Set window properties before showing
        ${lib.getExe pkgs.wmctrl} -i -r "$KITTY_WINDOW" -b add,above
        ${lib.getExe pkgs.wmctrl} -i -r "$KITTY_WINDOW" -e 0,$X_OFFSET,$Y_OFFSET,$WIDTH,$QUAKE_HEIGHT

        # Map and activate the window at the correct position
        ${lib.getExe pkgs.xdotool} windowmap "$KITTY_WINDOW"
        ${lib.getExe pkgs.xdotool} windowactivate "$KITTY_WINDOW"

        # Force position again after mapping (some WMs ignore initial position)
        sleep 0.1
        ${lib.getExe pkgs.xdotool} windowmove "$KITTY_WINDOW" "$X_OFFSET" "$Y_OFFSET"
      fi
    fi
  '';

  # Script to open fullscreen emacsclient on each monitor
  emacs-multiscreen = pkgs.writeShellScriptBin "emacs-multiscreen" ''
    # Get connected monitors and their geometries
    monitors=()
    while read -r line; do
      geom=$(echo "$line" | grep -oE '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' | head -1)
      if [ -n "$geom" ]; then
        monitors+=("$geom")
      fi
    done < <(${pkgs.xorg.xrandr}/bin/xrandr --current | grep ' connected')

    # Open one emacsclient per monitor, collecting window IDs
    new_windows=()
    for geom in "''${monitors[@]}"; do
      # Launch emacsclient and wait for its window
      emacsclient -c &
      sleep 0.3
      # Get the most recently created Emacs window
      win_id=$(${lib.getExe pkgs.xdotool} search --class Emacs 2>/dev/null | tail -1)
      if [ -n "$win_id" ]; then
        new_windows+=("$win_id:$geom")
      fi
    done

    # Move each window to its monitor and fullscreen
    for entry in "''${new_windows[@]}"; do
      win_id=$(echo "$entry" | cut -d: -f1)
      geom=$(echo "$entry" | cut -d: -f2-)
      x=$(echo "$geom" | cut -d+ -f2)
      y=$(echo "$geom" | cut -d+ -f3)

      # Move window to monitor
      ${lib.getExe pkgs.xdotool} windowmove "$win_id" "$x" "$y"
      sleep 0.1
      # Fullscreen with F11
      ${lib.getExe pkgs.xdotool} windowactivate --sync "$win_id" key F11
    done
  '';
in
{
  options.my = {
    # GNOME desktop integration
    gnome = {
      enable = lib.mkEnableOption "GNOME custom keybindings (tdrop, emacs-multiscreen)";

      numlockState = lib.mkEnableOption "keep numlock enabled on login";
    };
  };

  config = lib.mkIf cfg.enable {
    # GNOME dconf settings
    dconf.settings = {
      # Keep numlock enabled
      "org/gnome/desktop/peripherals/keyboard" = lib.mkIf cfg.numlockState {
        numlock-state = true;
      };
      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/kitty-quake/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/guake-toggle/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/emacs-gui/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/emacs-multiscreen/"
        ];
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/kitty-quake" = {
        name = "Kitty Quake";
        command = "kitty-quake";
        binding = "<Ctrl><Alt><Super>t";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/guake-toggle" = {
        name = "Guake Toggle";
        command = "guake -t -f";
        binding = "<Ctrl><Alt>t";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/emacs-gui" = {
        name = "Emacs GUI";
        command = "emacsclient -c";
        binding = "<Ctrl><Alt>e";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/emacs-multiscreen" = {
        name = "Emacs Multiscreen";
        command = "emacs-multiscreen";
        binding = "<Ctrl><Alt><Super>e";
      };
    };

    # Devilspie2 for forcing kitty-quake window position
    home.file.".config/devilspie2/kitty-quake.lua".text = ''
      if (get_window_class() == "kitty-quake") then
        set_window_geometry(0, 0, 1920, 1200)
        make_always_on_top()
        fullscreen()
      end
    '';

    # Auto-start devilspie2
    systemd.user.services.devilspie2 = {
      Unit = {
        Description = "Devilspie2 window matching daemon";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        ExecStart = "${lib.getExe pkgs.devilspie2}";
        Restart = "on-failure";
      };
    };

    # Helper scripts and tools for keybindings
    home.packages = [
      pkgs.xdotool
      pkgs.wmctrl
      pkgs.devilspie2
      kitty-quake
      emacs-multiscreen
    ];
  };
}
