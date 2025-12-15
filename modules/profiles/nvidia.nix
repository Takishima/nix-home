# NVIDIA GPU support profile - nixGL wrapper, btop-cuda
# Note: nixGL is only available on x86_64-linux
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  cfg = config.my.nvidia;
  getCmd = config.my.lib.getSystemCommand;
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;

  # Build nixGLNvidia with configured version (x86_64 only)
  nixglPkgs = lib.optionalAttrs isX86_64 (
    pkgs.callPackage "${inputs.nixgl}/nixGL.nix" {
      nvidiaVersion = cfg.driverVersion;
      nvidiaHash = cfg.driverHash;
      enable32bits = false;
    }
  );

  nixGLNvidia = lib.optionalAttrs isX86_64 (
    nixglPkgs.nixGLNvidia.overrideAttrs (old: {
      preferLocalBuild = true;
      allowSubstitutes = false;
    })
  );

  # Wrapper script with simpler name for use in PATH
  nixgl-nvidia = lib.optionalAttrs isX86_64 (
    pkgs.writeShellScriptBin "nixgl-nvidia" ''
      exec ${nixGLNvidia}/bin/nixGLNvidia-${cfg.driverVersion} "$@"
    ''
  );
in
{
  options.my.nvidia = {
    enable = mkEnableOption "NVIDIA GPU support (nixGL wrapper, btop-cuda)";

    driverVersion = mkOption {
      type = types.str;
      default = "580.105.08";
      description = "NVIDIA driver version to match system installation";
    };

    driverHash = mkOption {
      type = types.str;
      default = "sha256-2cboGIZy8+t03QTPpp3VhHn6HQFiyMKMjRdiV2MpNHU=";
      description = "SHA256 hash for NVIDIA driver download (SRI format)";
    };
  };

  config = mkIf cfg.enable {
    # NVIDIA driver version check on activation (x86_64 only)
    home.activation.checkNvidiaDriver = lib.mkIf isX86_64 (
      lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        CURRENT_VERSION=$(${getCmd "nvidia-smi"} --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "")
        EXPECTED_VERSION="${cfg.driverVersion}"

        if [ -z "$CURRENT_VERSION" ]; then
          echo ""
          echo "WARNING: Could not detect NVIDIA driver version"
          echo "nvidia-smi not found at configured path."
          echo "Configure path via: my.systemCommands.nvidia-smi.path"
          echo ""
        elif [ "$CURRENT_VERSION" != "$EXPECTED_VERSION" ]; then
          echo ""
          echo "ERROR: NVIDIA driver version mismatch!"
          echo "  System driver:   $CURRENT_VERSION"
          echo "  Expected driver: $EXPECTED_VERSION"
          echo ""
          echo "Update my.nvidia.driverVersion and my.nvidia.driverHash in your user config."
          echo "Get the hash with: nix-prefetch-url https://download.nvidia.com/XFree86/Linux-x86_64/$CURRENT_VERSION/NVIDIA-Linux-x86_64-$CURRENT_VERSION.run"
          echo ""
          exit 1
        fi
      ''
    );

    # NVIDIA power management check on activation (x86_64 only)
    # Checks modprobe config and systemd services for suspend/hibernate support
    home.activation.checkNvidiaPowerManagement = lib.mkIf isX86_64 (
      lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        NVIDIA_PM_ISSUES=""
        NVIDIA_PM_COMMANDS=""

        # Check modprobe config
        MODPROBE_CONF="/etc/modprobe.d/nvidia-power-management.conf"
        if [ ! -f "$MODPROBE_CONF" ]; then
          NVIDIA_PM_ISSUES="$NVIDIA_PM_ISSUES
          - Missing $MODPROBE_CONF"
          NVIDIA_PM_COMMANDS="$NVIDIA_PM_COMMANDS
        echo 'options nvidia NVreg_PreserveVideoMemoryAllocations=0' | sudo tee $MODPROBE_CONF"
        elif ! grep -q "NVreg_PreserveVideoMemoryAllocations=0" "$MODPROBE_CONF" 2>/dev/null; then
          NVIDIA_PM_ISSUES="$NVIDIA_PM_ISSUES
          - $MODPROBE_CONF missing NVreg_PreserveVideoMemoryAllocations=0"
          NVIDIA_PM_COMMANDS="$NVIDIA_PM_COMMANDS
        echo 'options nvidia NVreg_PreserveVideoMemoryAllocations=0' | sudo tee -a $MODPROBE_CONF"
        fi

        # Check systemd services
        for SERVICE in nvidia-suspend nvidia-hibernate nvidia-resume; do
          SERVICE_STATUS=$(${getCmd "systemctl"} is-enabled "$SERVICE.service" 2>/dev/null || echo "missing")
          case "$SERVICE_STATUS" in
            enabled|enabled-runtime|static|indirect|generated)
              # Service is properly configured
              ;;
            masked|masked-runtime)
              NVIDIA_PM_ISSUES="$NVIDIA_PM_ISSUES
          - $SERVICE.service is masked"
              NVIDIA_PM_COMMANDS="$NVIDIA_PM_COMMANDS
        sudo systemctl unmask $SERVICE.service && sudo systemctl enable $SERVICE.service"
              ;;
            *)
              NVIDIA_PM_ISSUES="$NVIDIA_PM_ISSUES
          - $SERVICE.service is $SERVICE_STATUS"
              NVIDIA_PM_COMMANDS="$NVIDIA_PM_COMMANDS
        sudo systemctl enable $SERVICE.service"
              ;;
          esac
        done

        if [ -n "$NVIDIA_PM_ISSUES" ]; then
          echo ""
          echo "WARNING: NVIDIA power management issues detected!"
          echo "Your laptop may not suspend/hibernate correctly."
          echo ""
          echo "Issues:$NVIDIA_PM_ISSUES"
          echo ""
          echo "Run these commands to fix:"
          echo "$NVIDIA_PM_COMMANDS"
          echo ""
        fi
      ''
    );

    # nixgl-nvidia wrapper in PATH (x86_64 only)
    home.packages = lib.optionals isX86_64 [ nixgl-nvidia ];

    # Environment variable for scripts that need the full path
    home.sessionVariables = lib.mkIf isX86_64 {
      NIXGL_NVIDIA = "${nixgl-nvidia}/bin/nixgl-nvidia";
    };

    # btop with CUDA support (overrides base btop package) - x86_64 only
    # Settings are configured in base.nix via my.monitoring.btop
    programs.btop.package = if isX86_64 then pkgs.btop-cuda else pkgs.btop;
  };
}
