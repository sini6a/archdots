#!/usr/bin/env bash

MODE="${1:-refresh}"

find_battery() {
    for dev in /sys/class/power_supply/*; do
        [ -d "$dev" ] || continue
        [ -f "$dev/type" ] || continue
        if [ "$(cat "$dev/type" 2>/dev/null)" = "Battery" ]; then
            echo "$dev"
            return 0
        fi
    done
    return 1
}

read_battery_info() {
    BATPATH="$(find_battery)" || return 1

    PERCENT="$(cat "$BATPATH/capacity" 2>/dev/null || echo "")"
    STATE="$(cat "$BATPATH/status" 2>/dev/null || echo "Unknown")"

    if [ -f "$BATPATH/power_now" ]; then
        RATE="$(awk '{printf "%.2f", $1 * 1e-6}' "$BATPATH/power_now" 2>/dev/null)"
    elif [ -f "$BATPATH/current_now" ] && [ -f "$BATPATH/voltage_now" ]; then
        RATE="$(awk 'BEGIN { printf "%.2f", ('"$(cat "$BATPATH/current_now" 2>/dev/null || echo 0)"' * '"$(cat "$BATPATH/voltage_now" 2>/dev/null || echo 0)"') / 1e12 }')"
    else
        RATE="0.00"
    fi

    export BATPATH PERCENT STATE RATE
    return 0
}

print_hidden() {
    printf '{"text":"","class":"hidden","alt":""}\n'
}

refresh() {
    if ! read_battery_info; then
        print_hidden
        return 0
    fi

    if [[ "$STATE" == "Charging" || "$STATE" == "pending-charge" ]]; then
        CLASS="charging"
    elif [[ "$PERCENT" =~ ^[0-9]+$ ]] && [ "$PERCENT" -le 10 ]; then
        CLASS="critical"
    elif [[ "$PERCENT" =~ ^[0-9]+$ ]] && [ "$PERCENT" -le 15 ]; then
        CLASS="warning"
    else
        CLASS="normal"
    fi

    if [[ "$STATE" == "Charging" || "$STATE" == "pending-charge" ]]; then
        TOOLTIP="+$RATE"
    else
        TOOLTIP="-$RATE"
    fi

    if command -v powerprofilesctl >/dev/null 2>&1; then
        PROFILE="$(powerprofilesctl get 2>/dev/null)"
    else
        PROFILE="balanced"
    fi

    case "$PROFILE" in
        performance) PROFILE="󰓅" ;;
        balanced)    PROFILE="󰗑" ;;
        power-saver) PROFILE="󰌪" ;;
        *)           PROFILE="󰗑" ;;
    esac

    printf '{"text":"%s","class":"%s","alt":"%s"}\n' "$PROFILE $PERCENT" "$CLASS" "$TOOLTIP W"
}

toggle_profile() {
    command -v powerprofilesctl >/dev/null 2>&1 || exit 0

    PROFILE="$(powerprofilesctl get 2>/dev/null)"
    case "$PROFILE" in
        power-saver) powerprofilesctl set performance ;;
        balanced)    powerprofilesctl set power-saver ;;
        performance) powerprofilesctl set balanced ;;
    esac
}

bar() {
    # Keep the indicator bar's width sized for the current screen. This runs
    # on the same interval as this "bar" mode (see custom/batteryindicator
    # in config.jsonc), so a resolution/scale change is picked up within
    # that interval without needing to restart waybar.
    "$(dirname "${BASH_SOURCE[0]}")/gen-indicator-width.sh"

    if ! read_battery_info; then
        printf '{"class":"hidden"}\n'
        return 0
    fi

    if [[ "$STATE" == "Full" || "$STATE" == "Not charging" ]]; then
        CLASS="full"
    elif [[ "$STATE" == "Charging" || "$STATE" == "pending-charge" ]]; then
        CLASS="charging"
    elif [[ "$PERCENT" =~ ^[0-9]+$ ]] && [ "$PERCENT" -le 10 ]; then
        CLASS="critical"
    elif [[ "$PERCENT" =~ ^[0-9]+$ ]] && [ "$PERCENT" -le 15 ]; then
        CLASS="warning"
    else
        CLASS="discharging"
    fi

    printf '{"class":"%s"}\n' "$CLASS"
}

case "$MODE" in
    refresh) refresh ;;
    toggle)  toggle_profile ;;
    bar)     bar ;;
    *)       refresh ;;
esac
