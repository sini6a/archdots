#!/usr/bin/env bash
#
# archdots installer: installs packages, then links this repo's configs into $HOME.
#
#   ./install.sh              # packages + config links
#   ./install.sh --no-packages  # config links only
#   ./install.sh --packages-only
#   ./install.sh --dry-run    # print what would happen, change nothing
#
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$HOME/.archdots-backup/$(date +%Y%m%d-%H%M%S)"

do_packages=1
do_links=1
dry_run=0

for arg in "$@"; do
  case "$arg" in
    --no-packages)   do_packages=0 ;;
    --packages-only) do_links=0 ;;
    --dry-run)       dry_run=1 ;;
    -h|--help)       sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  ! \033[0m%s\n' "$*"; }
run()  { if [ "$dry_run" -eq 1 ]; then printf '  would run: %s\n' "$*"; else "$@"; fi; }

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not root." >&2
  exit 1
fi

# ---------------------------------------------------------------- packages

install_packages() {
  command -v pacman >/dev/null || { warn "pacman not found; skipping packages."; return; }

  local pkgs
  mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$REPO/packages/pacman.txt")
  say "Installing ${#pkgs[@]} packages from the official repos"
  run sudo pacman -S --needed --noconfirm "${pkgs[@]}"

  if ! command -v yay >/dev/null; then
    say "Bootstrapping yay (AUR helper)"
    run sudo pacman -S --needed --noconfirm base-devel git
    local tmp
    tmp="$(mktemp -d)"
    run git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
    if [ "$dry_run" -eq 0 ]; then
      ( cd "$tmp/yay" && makepkg -si --noconfirm )
    fi
    run rm -rf "$tmp"
  fi

  local aur
  mapfile -t aur < <(grep -vE '^\s*(#|$)' "$REPO/packages/aur.txt")
  say "Installing ${#aur[@]} packages from the AUR"
  run yay -S --needed --noconfirm "${aur[@]}"
}

# ------------------------------------------------------------------- links

# Replace $2 with a symlink to $1, moving anything already there into $BACKUP.
link() {
  local src="$1" dest="$2"

  if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
    printf '  ok      %s\n' "${dest/#$HOME/~}"
    return
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    local rel="${dest/#$HOME\//}"
    printf '  backup  %s -> %s\n' "${dest/#$HOME/~}" "${BACKUP/#$HOME/~}/$rel"
    run mkdir -p "$BACKUP/$(dirname "$rel")"
    run mv "$dest" "$BACKUP/$rel"
  else
    printf '  link    %s\n' "${dest/#$HOME/~}"
  fi

  run mkdir -p "$(dirname "$dest")"
  run ln -s "$src" "$dest"
}

install_links() {
  say "Linking configs into ${CONFIG_HOME/#$HOME/~}"
  local entry
  for entry in "$REPO"/config/*; do
    link "$entry" "$CONFIG_HOME/$(basename "$entry")"
  done

  say "Linking dotfiles into ~"
  for entry in "$REPO"/home/.*; do
    case "$(basename "$entry")" in .|..) continue ;; esac
    link "$entry" "$HOME/$(basename "$entry")"
  done

  run chmod +x "$REPO"/config/waybar/modules/*.sh \
               "$REPO"/config/rofi/launchers/*.sh \
               "$REPO"/config/rofi/scripts/*.sh
}

# -------------------------------------------------------------------- main

[ "$do_packages" -eq 1 ] && install_packages
[ "$do_links" -eq 1 ] && install_links

say "Done."
[ -d "$BACKUP" ] && warn "Previous files were moved to ${BACKUP/#$HOME/~}"

cat <<'EOF'

Next steps:
  * Enable the services you want:
      systemctl enable --now NetworkManager power-profiles-daemon
  * The Hyprland config adapts to whatever display is attached. For a fixed
    multi-monitor layout, run `nwg-displays` and copy its values into the
    hl.monitor({...}) call near the top of config/hypr/hyprland.lua.
  * Start Hyprland with `start-hyprland` from a TTY, or enable a display
    manager of your choice.
EOF
