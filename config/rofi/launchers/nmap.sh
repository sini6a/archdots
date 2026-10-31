#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
HIST_FILE="${HIST_FILE:-$HOME/.local/share/rofi-nmap/history.txt}"
OUT_DIR="${OUT_DIR:-$HOME/.cache/nmap-scans}"
TERM_CMD="${TERM_CMD:-kitty}"

mkdir -p "$(dirname "$HIST_FILE")" "$OUT_DIR"
touch "$HIST_FILE"

# Show history, but allow typing new target
target="$(
  awk 'NF' "$HIST_FILE" | awk '!seen[$0]++' | rofi -dmenu \
    -p "nmap" \
    -theme-str 'configuration { show-icons: false; }'
)"

# Cancelled
[[ -z "${target:-}" ]] && exit 0

# Save target to history (most recent first, dedupe)
tmp="$(mktemp)"
{
  echo "$target"
  cat "$HIST_FILE"
} | awk 'NF' | awk '!seen[$0]++' > "$tmp"
mv "$tmp" "$HIST_FILE"

# Run scan
safe_target="${target//[^a-zA-Z0-9._:-]/_}"
ts="$(date +'%Y%m%d_%H%M%S')"
out_file="$OUT_DIR/nmap_${safe_target}_${ts}.txt"

cmd=(nmap -p- "$target")

# Watch + save output
"$TERM_CMD" -e bash -lc \
  "$(printf '%q ' "${cmd[@]}") |& tee $(printf '%q' "$out_file"); \
   echo; echo 'Saved to: $out_file'; echo; read -r -p 'Press Enter to close…' _"
