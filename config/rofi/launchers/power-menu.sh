#!/usr/bin/env bash
set -euo pipefail


options=$'Lock\nLogout\nSuspend\nReboot\nShutdown'

choice="$(
  printf '%s\n' "$options" | rofi -dmenu -i \
    -p "power" \
    -no-custom \
    -theme-str '
      configuration { show-icons: false; }
      listview { columns: 1; lines: 5; }
      element { padding: 6px 10px; }
    '
)"

[[ -z "${choice:-}" ]] && exit 0

case "$choice" in
  Lock)		sleep 0.25 && hyprlock ;;
  Logout)   hyprctl dispatch 'hl.dsp.exit()' ;;
  Suspend)  loginctl lock-session && systemctl suspend ;;
  Reboot)   exec systemctl reboot ;;
  Shutdown) exec systemctl poweroff ;;
esac
