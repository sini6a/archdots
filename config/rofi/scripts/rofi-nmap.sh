#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
HIST_FILE="${HIST_FILE:-$HOME/.local/share/rofi-nmap/history.txt}"
OUT_DIR="${OUT_DIR:-$HOME/.cache/nmap-scans}"
TERM_CMD="${TERM_CMD:-kitty}"

mkdir -p "$(dirname "$HIST_FILE")" "$OUT_DIR"
touch "$HIST_FILE"

have() { command -v "$1" >/dev/null 2>&1; }

# Helper: add to history (most recent first, dedupe)
add_history() {
  local entry="$1" tmp
  tmp="$(mktemp)"
  {
    echo "$entry"
    cat "$HIST_FILE"
  } | awk 'NF' | awk '!seen[$0]++' > "$tmp"
  mv "$tmp" "$HIST_FILE"
}

# ---- Action phase ----
if [[ "${ROFI_RETV:-0}" -ne 0 ]]; then

  # SHIFT+DELETE → delete entry (ROFI_RETV=3)
  if [[ "${ROFI_RETV}" -eq 3 ]]; then
    if [[ -n "${ROFI_INFO:-}" && "${ROFI_INFO}" == target:* ]]; then
      delete_target="${ROFI_INFO#target:}"
      tmp="$(mktemp)"
      grep -Fxv -- "$delete_target" "$HIST_FILE" > "$tmp" || true
      mv "$tmp" "$HIST_FILE"
    fi
    exit 0
  fi

  # ENTER → run scan / or just save
  target="${1:-}"
  [[ -z "${target}" ]] && target="${ROFI_INPUT:-}"

  if [[ -n "${ROFI_INFO:-}" && "${ROFI_INFO}" == target:* ]]; then
    target="${ROFI_INFO#target:}"
  fi

  target="$(printf '%s' "$target" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -z "${target}" ]] && exit 0

  # ✅ ALWAYS save to history, even if nmap is missing
  add_history "$target"

  # If nmap missing, stop here (but history is saved)
  if ! have nmap; then
    notify-send "rofi-nmap" "nmap not installed."
    exit 0
  fi

  if ! have "$TERM_CMD"; then
    notify-send "rofi-nmap" "Saved \"$target\" to history (terminal not found: $TERM_CMD)."
    exit 0
  fi

  safe_target="${target//[^a-zA-Z0-9._:-]/_}"
  ts="$(date +'%Y%m%d_%H%M%S')"
  out_file="$OUT_DIR/nmap_${safe_target}_${ts}.txt"

  scan_cmd="$(
    printf 'nmap -p- %q |& tee %q; ' "$target" "$out_file"
    printf "echo; echo 'Saved to: %s'; echo; read -r -p 'Press Enter to close…' _" "$out_file"
  )"

  setsid "$TERM_CMD" -e bash -lc "$scan_cmd" </dev/null >/dev/null 2>&1 & disown
  notify-send "rofi-nmap" "Started scan for $target"

  exit 0
fi

# ---- Listing phase ----
# If nmap missing, show a nonselectable warning row (still allow user to see history if you want)
if ! have nmap; then
  printf '\x00prompt\x1fnmap (not installed)\n'
  # You can exit here to show ONLY the message:
fi

awk 'NF' "$HIST_FILE" | awk '!seen[$0]++' | while IFS= read -r line; do
  printf '%s\x00info\x1ftarget:%s\n' "$line" "$line"
done
