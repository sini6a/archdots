#!/usr/bin/env bash
# Regenerates modules/indicator-width.css: the minimum content width that makes the
# battery-indicator bar (#waybar.indicator #custom-batteryindicator) visually
# span the width of the bar.
#
# Why this exists: GTK CSS (what waybar uses) has no percentage or viewport-
# relative width units, so a module can't be told "fill available space" in
# plain CSS. Set a minimum content width based on the monitor's resolution
# and scale, excluding the margins and borders. This avoids depending on
# the width of the invisible space character.
# - it used to be hand-calculated once and hardcoded, which broke on any other
# screen. This script recomputes it from the current output instead, so it
# self-adjusts when you change resolution/scaling.
#
# Called from bat-pp.sh's "bar" mode, which already runs on the interval set
# for "custom/batteryindicator" in config.jsonc - no separate scheduling needed.
#
# Keep these in sync with the "indicator" bar block in config.jsonc and the
# #waybar.indicator / #custom-batteryindicator rules in style.css. margin-left
# and margin-right here must equal the indicator bar's own margins, which in
# turn must equal the main bar's margins - otherwise the two bars span
# different widths and the "battery bar" won't line up with the main bar.
MARGIN_LEFT=16
MARGIN_RIGHT=16
BORDER_WIDTH=2   # #custom-batteryindicator border width (px)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_CSS="$SCRIPT_DIR/indicator-width.css"

command -v hyprctl >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Prefer the focused monitor; fall back to the first one reported.
mon="$(hyprctl monitors -j 2>/dev/null | jq -c '([.[] | select(.focused == true)] + .)[0] // empty')"
[ -n "$mon" ] || exit 0

width="$(jq -rn --argjson m "$mon" '$m.width // empty')"
scale="$(jq -rn --argjson m "$mon" '$m.scale // empty')"
[ -n "$width" ] && [ -n "$scale" ] || exit 0

# Round the logical output width: fractional scales can yield 1439.9999
# for an actual 1440px output. Truncating would shorten the outline by 1px.
content_width="$(awk -v w="$width" -v s="$scale" -v ml="$MARGIN_LEFT" -v mr="$MARGIN_RIGHT" \
    -v bw="$BORDER_WIDTH" \
    'BEGIN { printf "%.0f", (w / s) - ml - mr - (2 * bw) }' 2>/dev/null)"
[ -n "$content_width" ] || exit 0
[ "$content_width" -gt 0 ] 2>/dev/null || exit 0

new_rule="#waybar.indicator #custom-batteryindicator { min-width: ${content_width}px; }"

# Only (re)write when the value actually changed, so we don't trigger
# waybar's reload_style_on_change every few seconds for no reason.
if [ ! -f "$OUT_CSS" ] || [ "$(cat "$OUT_CSS" 2>/dev/null)" != "$new_rule" ]; then
    printf '%s\n' "$new_rule" > "$OUT_CSS"
fi
