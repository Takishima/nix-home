# Base profile - essential configuration for all users
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.my;

  # nix-size - Show NAR and closure sizes for store paths or flake references
  nix-size = pkgs.runCommandLocal "nix-size" { } ''
    mkdir -p $out/bin
    substitute ${../../scripts/nix-size} $out/bin/nix-size \
      --replace-fail '#!/usr/bin/env bash' '#!${lib.getExe pkgs.bash}' \
      --replace-fail 'nix ' '${lib.getExe pkgs.nix} ' \
      --replace-fail '| bc)' '| ${lib.getExe pkgs.bc})' \
      --replace-fail '| awk' '| ${lib.getExe pkgs.gawk}'
    chmod +x $out/bin/nix-size
  '';
in
{
  options.my.monitoring = {
    btop = {
      updateMs = mkOption {
        type = types.int;
        default = 500;
        description = "Update time in milliseconds (2000+ recommended for better graph samples)";
      };
      colorTheme = mkOption {
        type = types.str;
        default = "Default";
        description = "Color theme for btop";
      };
      themeBackground = mkOption {
        type = types.bool;
        default = true;
        description = "Use theme background if true, else use terminal background";
      };
      truecolor = mkOption {
        type = types.bool;
        default = true;
        description = "Use 24-bit truecolor (false converts to 256 colors)";
      };
      roundedCorners = mkOption {
        type = types.bool;
        default = true;
        description = "Rounded corners on boxes";
      };
      graphSymbol = mkOption {
        type = types.str;
        default = "braille";
        description = "Default graph symbol: braille, block, or tty";
      };
      shownBoxes = mkOption {
        type = types.str;
        default = "cpu mem net proc";
        description = "Which boxes to show (cpu mem net proc gpu0-gpu5)";
      };
      procSorting = mkOption {
        type = types.str;
        default = "cpu lazy";
        description = "Process sorting method";
      };
      procPerCore = mkOption {
        type = types.bool;
        default = false;
        description = "Show process CPU usage per core or total CPU power";
      };
      procMemBytes = mkOption {
        type = types.bool;
        default = true;
        description = "Show process memory as bytes instead of percent";
      };
      procCpuGraphs = mkOption {
        type = types.bool;
        default = true;
        description = "Show cpu graph for each process";
      };
      cpuGraphUpper = mkOption {
        type = types.str;
        default = "Auto";
        description = "CPU graph upper box mode (Auto, total, user, system, etc.)";
      };
      cpuGraphLower = mkOption {
        type = types.str;
        default = "Auto";
        description = "CPU graph lower box mode (Auto, total, user, system, etc.)";
      };
      cpuInvertLower = mkOption {
        type = types.bool;
        default = true;
        description = "Invert the lower CPU graph";
      };
      showUptime = mkOption {
        type = types.bool;
        default = true;
        description = "Show system uptime";
      };
      showCpuWatts = mkOption {
        type = types.bool;
        default = true;
        description = "Show CPU power consumption in watts";
      };
      checkTemp = mkOption {
        type = types.bool;
        default = true;
        description = "Enable temperature monitoring";
      };
      showCoretemp = mkOption {
        type = types.bool;
        default = true;
        description = "Show temperatures for cpu cores";
      };
      showCpuFreq = mkOption {
        type = types.bool;
        default = true;
        description = "Show CPU frequency";
      };
      clockFormat = mkOption {
        type = types.str;
        default = "%X";
        description = "Clock format at top of screen (strftime format, empty to disable)";
      };
      memGraphs = mkOption {
        type = types.bool;
        default = true;
        description = "Show graphs instead of meters for memory values";
      };
      showSwap = mkOption {
        type = types.bool;
        default = true;
        description = "Show swap memory in memory box";
      };
      swapDisk = mkOption {
        type = types.bool;
        default = true;
        description = "Show swap as a disk";
      };
      showDisks = mkOption {
        type = types.bool;
        default = true;
        description = "Show disks info in mem box";
      };
      onlyPhysical = mkOption {
        type = types.bool;
        default = true;
        description = "Filter out non-physical disks";
      };
      useFstab = mkOption {
        type = types.bool;
        default = true;
        description = "Read disks list from /etc/fstab";
      };
      showIoStat = mkOption {
        type = types.bool;
        default = true;
        description = "Show io activity percentage";
      };
      netAuto = mkOption {
        type = types.bool;
        default = true;
        description = "Use network graphs auto rescaling mode";
      };
      netSync = mkOption {
        type = types.bool;
        default = true;
        description = "Sync auto scaling for download and upload";
      };
      showBattery = mkOption {
        type = types.bool;
        default = true;
        description = "Show battery stats if battery is present";
      };
      showBatteryWatts = mkOption {
        type = types.bool;
        default = true;
        description = "Show power stats of battery";
      };
      nvmlMeasurePcieSpeeds = mkOption {
        type = types.bool;
        default = true;
        description = "Measure PCIe throughput on NVIDIA cards";
      };
      rsmiMeasurePcieSpeeds = mkOption {
        type = types.bool;
        default = true;
        description = "Measure PCIe throughput on AMD cards";
      };
      gpuMirrorGraph = mkOption {
        type = types.bool;
        default = true;
        description = "Horizontally mirror the GPU graph";
      };
    };
  };

  config = mkIf cfg.profiles.base {
    # Register base scripts in unified command registry
    my.commands.scripts = {
      nix-size = {
        desc = "Show NAR and closure sizes for store paths";
        package = nix-size;
      };
    };

    # Install scripts from unified command registry
    home.packages =
      (with pkgs; [
        # Modern CLI replacements
        bat # cat replacement
        eza # ls replacement
        fd # find replacement
        ripgrep # grep replacement
        dust # du replacement

        # Diff tools
        difftastic # structural diff
        dyff # YAML/JSON diff

        # Utilities
        fzf # fuzzy finder
        just # command runner
        lnav # log file navigator
      ])
      ++ lib.mapAttrsToList (name: c: c.package) config.my.commands.scripts;
    # Set user identity from options
    home = {
      username = cfg.user.name;
      homeDirectory = cfg.user.homeDirectory;
      stateVersion = "24.11";
    };

    # Home Manager self-management
    programs.home-manager.enable = true;

    # Required for standalone Nix on non-NixOS Linux
    targets.genericLinux.enable = true;

    # XDG directories
    xdg.enable = true;

    programs.parallel.enable = true;

    # Starship prompt moved to modules/profiles/prompt.nix

    # Direnv with nix-direnv
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      config.global.hide_env_diff = true;
    };

    # Shell configuration (bash/fish) moved to modules/profiles/shell.nix
    # Terminal configuration (kitty) moved to modules/profiles/terminal.nix

    # btop (base version without CUDA)
    programs.btop = {
      enable = true;
      settings = {
        # Display settings
        color_theme = cfg.monitoring.btop.colorTheme;
        theme_background = cfg.monitoring.btop.themeBackground;
        truecolor = cfg.monitoring.btop.truecolor;
        rounded_corners = cfg.monitoring.btop.roundedCorners;
        graph_symbol = cfg.monitoring.btop.graphSymbol;
        shown_boxes = cfg.monitoring.btop.shownBoxes;
        update_ms = cfg.monitoring.btop.updateMs;
        clock_format = cfg.monitoring.btop.clockFormat;

        # Process settings
        proc_sorting = cfg.monitoring.btop.procSorting;
        proc_per_core = cfg.monitoring.btop.procPerCore;
        proc_mem_bytes = cfg.monitoring.btop.procMemBytes;
        proc_cpu_graphs = cfg.monitoring.btop.procCpuGraphs;

        # CPU settings
        cpu_graph_upper = cfg.monitoring.btop.cpuGraphUpper;
        cpu_graph_lower = cfg.monitoring.btop.cpuGraphLower;
        cpu_invert_lower = cfg.monitoring.btop.cpuInvertLower;
        show_uptime = cfg.monitoring.btop.showUptime;
        show_cpu_watts = cfg.monitoring.btop.showCpuWatts;
        check_temp = cfg.monitoring.btop.checkTemp;
        show_coretemp = cfg.monitoring.btop.showCoretemp;
        show_cpu_freq = cfg.monitoring.btop.showCpuFreq;

        # Memory settings
        mem_graphs = cfg.monitoring.btop.memGraphs;
        show_swap = cfg.monitoring.btop.showSwap;
        swap_disk = cfg.monitoring.btop.swapDisk;
        show_disks = cfg.monitoring.btop.showDisks;
        only_physical = cfg.monitoring.btop.onlyPhysical;
        use_fstab = cfg.monitoring.btop.useFstab;
        show_io_stat = cfg.monitoring.btop.showIoStat;

        # Network settings
        net_auto = cfg.monitoring.btop.netAuto;
        net_sync = cfg.monitoring.btop.netSync;

        # Battery settings
        show_battery = cfg.monitoring.btop.showBattery;
        show_battery_watts = cfg.monitoring.btop.showBatteryWatts;

        # GPU settings
        nvml_measure_pcie_speeds = cfg.monitoring.btop.nvmlMeasurePcieSpeeds;
        rsmi_measure_pcie_speeds = cfg.monitoring.btop.rsmiMeasurePcieSpeeds;
        gpu_mirror_graph = cfg.monitoring.btop.gpuMirrorGraph;
      };
    };

    # GDB configuration
    home.file.".gdbinit".text = ''
      set auto-load local-gdbinit on
      add-auto-load-safe-path /
      set debuginfod enabled on
      set debuginfod urls http://127.0.0.1:1949
    '';

    # Clangd configuration
    xdg.configFile."clangd/config.yaml".text = ''
      ---
      CompileFlags:
        Add: [-std=c++20,-ferror-limit=0]
        Remove: -W*

      Diagnostics:
        UnusedIncludes: None

      InlayHints:
        Designators: true
        Enabled: true
        ParameterNames: true
        DeducedTypes: true
    '';
  };
}
