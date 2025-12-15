# ROS2 development support profile - sysctl checks for Cyclone DDS networking
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.my.ros2;
  sysctlCfg = cfg.sysctl;
in
{
  options.my.ros2 = {
    enable = mkEnableOption "ROS2 development support (sysctl checks for Cyclone DDS)";

    sysctlConfigPath = mkOption {
      type = types.str;
      default = "/etc/sysctl.d/10-cyclone-max.conf";
      description = "Path to sysctl configuration file for ROS2/Cyclone DDS networking";
    };

    # Expected sysctl values for Cyclone DDS
    sysctl = {
      ipfragTime = mkOption {
        type = types.int;
        default = 3;
        description = "IP fragment timeout in seconds (net.ipv4.ipfrag_time)";
      };

      ipfragHighThresh = mkOption {
        type = types.int;
        default = 134217728;
        description = "IP fragment high threshold in bytes (net.ipv4.ipfrag_high_thresh, 128 MiB)";
      };

      rmemMax = mkOption {
        type = types.int;
        default = 20971520;
        description = "Max receive buffer size in bytes (net.core.rmem_max, 20 MiB)";
      };

      wmemMax = mkOption {
        type = types.int;
        default = 20971520;
        description = "Max send buffer size in bytes (net.core.wmem_max, 20 MiB)";
      };
    };
  };

  config = mkIf cfg.enable {
    # ROS2 sysctl configuration check on activation
    # Verifies kernel parameters required for Cyclone DDS networking
    home.activation.checkRos2Sysctl = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
            ROS2_SYSCTL_ISSUES=""
            ROS2_SYSCTL_COMMANDS=""
            SYSCTL_FILE="${cfg.sysctlConfigPath}"

            # Helper to check a sysctl value
            check_sysctl() {
              local key="$1"
              local expected="$2"
              local current

              current=$(${pkgs.procps}/bin/sysctl -n "$key" 2>/dev/null || echo "unknown")

              if [ "$current" = "unknown" ]; then
                ROS2_SYSCTL_ISSUES="$ROS2_SYSCTL_ISSUES
                - $key: cannot read (missing kernel support?)"
              elif [ "$current" -lt "$expected" ] 2>/dev/null; then
                ROS2_SYSCTL_ISSUES="$ROS2_SYSCTL_ISSUES
                - $key: $current (expected >= $expected)"
                ROS2_SYSCTL_COMMANDS="$ROS2_SYSCTL_COMMANDS
              sudo sysctl -w $key=$expected"
              fi
            }

            # Check runtime sysctl values
            check_sysctl "net.ipv4.ipfrag_time" "${toString sysctlCfg.ipfragTime}"
            check_sysctl "net.ipv4.ipfrag_high_thresh" "${toString sysctlCfg.ipfragHighThresh}"
            check_sysctl "net.core.rmem_max" "${toString sysctlCfg.rmemMax}"
            check_sysctl "net.core.wmem_max" "${toString sysctlCfg.wmemMax}"

            # Check if persistent config file exists
            if [ ! -f "$SYSCTL_FILE" ]; then
              ROS2_SYSCTL_ISSUES="$ROS2_SYSCTL_ISSUES
                - Missing persistent config: $SYSCTL_FILE"
              ROS2_SYSCTL_COMMANDS="$ROS2_SYSCTL_COMMANDS

              # Create persistent sysctl config for ROS2/Cyclone DDS:
              sudo tee $SYSCTL_FILE << 'SYSCTL_EOF'
      # ROS2 Cyclone DDS network settings
      # IP fragmentation settings
      net.ipv4.ipfrag_time=${toString sysctlCfg.ipfragTime}
      net.ipv4.ipfrag_high_thresh=${toString sysctlCfg.ipfragHighThresh}
      # Network buffer sizes
      net.core.rmem_max=${toString sysctlCfg.rmemMax}
      net.core.wmem_max=${toString sysctlCfg.wmemMax}
      SYSCTL_EOF"
            fi

            if [ -n "$ROS2_SYSCTL_ISSUES" ]; then
              echo ""
              echo "WARNING: ROS2/Cyclone DDS sysctl configuration issues detected!"
              echo "ROS2 nodes may fail to launch or have networking problems."
              echo ""
              echo "Issues:$ROS2_SYSCTL_ISSUES"
              echo ""
              echo "Run these commands to fix:$ROS2_SYSCTL_COMMANDS"
              echo ""
            fi
    '';
  };
}
