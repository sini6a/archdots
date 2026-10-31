#!/usr/bin/env bash
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

# -----------------------------
# ACTION PHASE
# -----------------------------
if [[ "${ROFI_RETV:-0}" -ne 0 ]]; then
  case "${ROFI_INFO:-}" in
    toggle:on)
      nmcli radio wifi on >/dev/null 2>&1 || notify-send "Wi-Fi" "Failed to enable Wi-Fi"
      ;;
    toggle:off)
      nmcli radio wifi off >/dev/null 2>&1 || notify-send "Wi-Fi" "Failed to disable Wi-Fi"
      ;;
    ssid:*)
      ssid="${ROFI_INFO#ssid:}"

      saved="$(nmcli -t -g NAME connection show 2>/dev/null || true)"
      if echo "$saved" | grep -Fxq "$ssid"; then
        nmcli connection up id "$ssid" >/dev/null \
          && notify-send "Connection Established" "Connected to \"$ssid\"."
      else
        if [[ "${ROFI_DATA:-}" == "lock" ]]; then
          pass="$(rofi -dmenu -password -p "Password:" )"
          [[ -z "$pass" ]] && exit 0
          nmcli device wifi connect "$ssid" password "$pass" >/dev/null \
            && notify-send "Connection Established" "Connected to \"$ssid\"."
        else
          nmcli device wifi connect "$ssid" >/dev/null \
            && notify-send "Connection Established" "Connected to \"$ssid\"."
        fi
      fi
      ;;
  esac
  exit 0
fi

# -----------------------------
# LISTING PHASE
# -----------------------------

# 1️⃣ Check nmcli exists
if ! have nmcli; then
  printf '\x00prompt\x1fwifi (nmcli not installed)\n'
  exit 0
fi

# 2️⃣ Check NetworkManager running
if ! nmcli general status >/dev/null 2>&1; then
  printf '\x00prompt\x1fwifi (NetworkManager not running)\n'
  exit 0
fi

# 3️⃣ Detect Wi-Fi adapter
wifi_dev="$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')"

if [[ -z "$wifi_dev" ]]; then
  printf '\x00prompt\x1fwifi (no adapter)\n'
  exit 0
fi

# 4️⃣ Toggle row
wifi_radio="$(nmcli -t -f WIFI general | tr -d '\r')"

if [[ "$wifi_radio" == "enabled" ]]; then
  printf '󰖪  Disable Wi-Fi\x00info\x1ftoggle:off\n'
else
  printf '󰖩  Enable Wi-Fi\x00info\x1ftoggle:on\n'
fi

# 5️⃣ Network list
nmcli -t -f SECURITY,SSID device wifi list ifname "$wifi_dev" 2>/dev/null \
| sed '/:$/d' \
| awk -F: '
    function is_lock(sec){ return !(sec=="" || sec=="--") }
    {
      ssid=$2
      if (ssid=="") next
      if (is_lock($1)) {
        printf " %s\x00info\x1fssid:%s\x00data\x1flock\n", ssid, ssid
      } else {
        printf " %s\x00info\x1fssid:%s\x00data\x1fopen\n", ssid, ssid
      }
    }
  ' || true
