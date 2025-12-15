#!/usr/bin/env bash
# Power management utility - controls GNOME power profile and CPU governor
set -euo pipefail

POWERPROFILESCTL="@powerprofilesctl@"
CPUPOWER="@cpupower@"

has_power_profiles() {
  $POWERPROFILESCTL get &>/dev/null
}

get_profile() {
  if has_power_profiles; then
    $POWERPROFILESCTL get
  else
    echo "N/A (power-profiles-daemon not running)"
  fi
}

show_status() {
  echo "Profile:  $(get_profile)"
  echo "Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
}

show_help() {
  echo "Usage: hm-power <command> [args]"
  echo ""
  echo "Commands:"
  echo "  status                Show current profile and governor"
  echo "  profile <name>        Set GNOME power profile (performance|balanced|power-saver)"
  echo "  governor <name>       Set CPU governor (performance|powersave) [requires sudo]"
  echo "  preset <name>         Set both profile and governor:"
  echo "                          performance - profile: performance, governor: performance"
  echo "                          balanced    - profile: balanced, governor: powersave"
  echo "                          powersave   - profile: power-saver, governor: powersave"
}

set_profile() {
  local profile="${1:-}"
  if [[ -z $profile ]]; then
    echo "Usage: hm-power profile <performance|balanced|power-saver>" >&2
    return 1
  fi
  if ! has_power_profiles; then
    echo "Error: power-profiles-daemon not running" >&2
    return 1
  fi
  $POWERPROFILESCTL set "$profile"
}

set_governor() {
  local governor="${1:-}"
  if [[ -z $governor ]]; then
    echo "Usage: hm-power governor <performance|powersave>" >&2
    return 1
  fi
  sudo "$CPUPOWER" frequency-set -g "$governor"
}

case "${1:-}" in
"")
  show_status
  echo ""
  show_help
  ;;
status)
  show_status
  ;;
profile)
  set_profile "${2:-}"
  ;;
governor)
  set_governor "${2:-}"
  ;;
preset)
  case "${2:-}" in
  performance)
    has_power_profiles && $POWERPROFILESCTL set performance
    sudo "$CPUPOWER" frequency-set -g performance
    ;;
  balanced)
    has_power_profiles && $POWERPROFILESCTL set balanced
    sudo "$CPUPOWER" frequency-set -g powersave
    ;;
  powersave | power-saver)
    has_power_profiles && $POWERPROFILESCTL set power-saver
    sudo "$CPUPOWER" frequency-set -g powersave
    ;;
  *)
    echo "Usage: hm-power preset <performance|balanced|powersave>" >&2
    exit 1
    ;;
  esac
  ;;
*)
  echo "Unknown command: $1" >&2
  show_help
  exit 1
  ;;
esac
