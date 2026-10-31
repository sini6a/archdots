#!/usr/bin/env bash
#
# Build a bootable Arch live ISO running the archdots desktop, for real hardware.
#
#   sudo iso/build-iso.sh deps     # install archiso
#   sudo iso/build-iso.sh aurrepo  # build/harvest the AUR packages into a local repo
#   sudo iso/build-iso.sh profile  # generate the archiso profile from releng
#   sudo iso/build-iso.sh build    # run mkarchiso (15-30 min)
#        iso/build-iso.sh run      # boot the ISO in QEMU to check it
#   sudo iso/build-iso.sh teardown # delete everything it made
#
#   sudo iso/build-iso.sh all      # aurrepo + profile + build
#
# Live user is 'live' with password 'live', autologin on tty1 into Hyprland.
#
# Environment:
#   ARCHDOTS_WORK   build directory (default /var/lib/archdots-iso)
#   AUR_METHOD      auto | makepkg | container  (how to obtain the AUR packages)
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd -- "$HERE/.." && pwd)"
ROOTFS=/var/lib/machines/archdots-test
WORK="${ARCHDOTS_WORK:-/var/lib/archdots-iso}"
PROFILE="$WORK/profile"
AURREPO="$WORK/aurrepo"
OUT="$WORK/out"
LIVEUSER=live
LIVEPASS=live

say()  { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  PASS \033[0m%s\n' "$*"; }
bad()  { printf '\033[1;31m  !! \033[0m%s\n' "$*"; }
info() { printf '       %s\n' "$*"; }

need_root() { [ "$(id -u)" -eq 0 ] || { echo "'$1' needs root. Run: sudo $0 $1" >&2; exit 1; }; }

AUR_PKGS=(dracula-gtk-theme dracula-icons-git soteria-git wttrbar)

# GPU and firmware bits releng does not ship, for booting unfamiliar hardware.
# libva/vdpau drivers are part of mesa itself now, so they are not listed.
EXTRA_PKGS=(
  mesa vulkan-radeon vulkan-intel vulkan-nouveau vulkan-icd-loader
  networkmanager
  sudo
  git
)

cmd_deps() {
  say "Installing archiso"
  pacman -S --needed --noconfirm archiso
  ok "archiso installed"
}

# ---------------------------------------------------------------- AUR repo

cmd_aurrepo() {
  command -v repo-add >/dev/null || { bad "repo-add missing (pacman package)"; exit 1; }
  mkdir -p "$AURREPO"
  local method="${AUR_METHOD:-auto}"

  # Reuse anything already built, so repeat runs and local rebuilds are cheap.
  say "Looking for already-built AUR packages"
  local found=0 f
  for d in "$ROOTFS/home/tester/.cache/yay" "$ROOTFS/home/tester/isobuild" \
           "$ROOTFS/var/cache/pacman/pkg" "$WORK/aurbuild"; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do
      cp -n "$f" "$AURREPO/" 2>/dev/null && found=$((found+1))
    done < <(find "$d" -name '*.pkg.tar.zst' 2>/dev/null \
             | grep -E "$(IFS='|'; echo "${AUR_PKGS[*]}")" || true)
  done
  info "harvested $found package file(s)"

  local missing=()
  for p in "${AUR_PKGS[@]}"; do
    compgen -G "$AURREPO/${p}-*.pkg.tar.zst" >/dev/null || missing+=("$p")
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    # makepkg refuses to run as root, so builds need an unprivileged user
    # either way. 'container' uses the nspawn test rootfs; 'makepkg' builds
    # right here, which is what CI needs since it has no nested container.
    if [ "$method" = auto ]; then
      if [ -d "$ROOTFS/etc" ]; then method=container; else method=makepkg; fi
    fi
    say "Building ${missing[*]} via $method"

    if [ "$method" = container ]; then
      [ -d "$ROOTFS/etc" ] || { bad "No container at $ROOTFS"; exit 1; }
      systemd-nspawn -q -D "$ROOTFS" --bind-ro=/etc/resolv.conf -u tester \
        /bin/bash -euo pipefail -c "
          mkdir -p ~/isobuild && cd ~/isobuild
          for p in ${missing[*]}; do
            rm -rf \$p
            git clone -q https://aur.archlinux.org/\$p.git
            ( cd \$p && makepkg -sf --noconfirm --needed )
          done
        "
      while IFS= read -r f; do cp -f "$f" "$AURREPO/"; done \
        < <(find "$ROOTFS/home/tester/isobuild" -name '*.pkg.tar.zst' 2>/dev/null)
    else
      local BUILDER="${AUR_BUILD_USER:-archdots-build}"
      local BDIR="$WORK/aurbuild"
      id "$BUILDER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$BUILDER"
      # Build deps are installed with pacman, which needs root.
      printf '%s ALL=(ALL) NOPASSWD: /usr/bin/pacman\n' "$BUILDER" \
        > /etc/sudoers.d/99-archdots-build
      chmod 440 /etc/sudoers.d/99-archdots-build
      mkdir -p "$BDIR"; chown -R "$BUILDER" "$BDIR"
      sudo -u "$BUILDER" /bin/bash -euo pipefail -c "
          cd '$BDIR'
          for p in ${missing[*]}; do
            rm -rf \$p
            git clone -q https://aur.archlinux.org/\$p.git
            ( cd \$p && makepkg -sf --noconfirm --needed )
          done
        "
      rm -f /etc/sudoers.d/99-archdots-build
      while IFS= read -r f; do cp -f "$f" "$AURREPO/"; done \
        < <(find "$BDIR" -name '*.pkg.tar.zst' 2>/dev/null)
    fi
  fi

  # Debug subpackages are not wanted in the ISO.
  rm -f "$AURREPO"/*-debug-*.pkg.tar.zst

  say "Indexing the local repo"
  rm -f "$AURREPO"/archdots.db* "$AURREPO"/archdots.files*
  repo-add -q "$AURREPO/archdots.db.tar.gz" "$AURREPO"/*.pkg.tar.zst
  ok "local repo at $AURREPO"
  local gone=0
  for p in "${AUR_PKGS[@]}"; do
    printf '       %-22s ' "$p"
    if compgen -G "$AURREPO/${p}-*.pkg.tar.zst" >/dev/null; then
      echo "present"
    else
      echo "MISSING"; gone=1
    fi
  done
  [ "$gone" -eq 0 ] || { bad "Some AUR packages are missing; the ISO would be incomplete."; exit 1; }
}

# ----------------------------------------------------------------- profile

cmd_profile() {
  [ -d /usr/share/archiso/configs/releng ] || { bad "archiso not installed. Run: sudo $0 deps"; exit 1; }
  [ -f "$AURREPO/archdots.db.tar.gz" ] || { bad "No local AUR repo. Run: sudo $0 aurrepo"; exit 1; }
  [ -d "$REPO/config" ] || { bad "No dotfiles repo at $REPO"; exit 1; }

  say "Copying the releng profile"
  rm -rf "$PROFILE"; mkdir -p "$PROFILE"
  cp -a /usr/share/archiso/configs/releng/. "$PROFILE/"
  local base_count
  base_count=$(grep -cvE '^\s*(#|$)' "$PROFILE/packages.x86_64")
  info "releng ships $base_count packages"

  say "Adding the archdots package set"
  {
    printf '\n# --- archdots ---\n'
    grep -vE '^\s*(#|$)' "$REPO/packages/pacman.txt"
    printf '%s\n' "${EXTRA_PKGS[@]}"
    printf '%s\n' "${AUR_PKGS[@]}"
  } >> "$PROFILE/packages.x86_64"
  # Deduplicate: releng and archdots overlap (nmap, at least).
  sort -u -o "$PROFILE/packages.x86_64" <(grep -vE '^\s*(#|$)' "$PROFILE/packages.x86_64")
  ok "$(grep -cvE '^\s*(#|$)' "$PROFILE/packages.x86_64") packages total"

  say "Pointing the build at the local AUR repo"
  cat >> "$PROFILE/pacman.conf" <<EOF

[archdots]
SigLevel = Optional TrustAll
Server = file://$AURREPO
EOF
  ok "[archdots] repo added to the build's pacman.conf"

  local AIR="$PROFILE/airootfs"

  say "Baking the dotfiles into /etc/skel"
  mkdir -p "$AIR/etc/skel/.config"
  cp -a "$REPO/config/." "$AIR/etc/skel/.config/"
  cp -a "$REPO/home/.gtkrc-2.0" "$AIR/etc/skel/.gtkrc-2.0"
  # Ship the repo itself so the live session can install to disk. .git is kept
  # on purpose: the installed system gets a real repo, so editing a symlinked
  # config shows up as drift in `git status` instead of silently diverging.
  mkdir -p "$AIR/usr/share/archdots"
  cp -a "$REPO/." "$AIR/usr/share/archdots/"
  # Never bake build output into the image it came from. CI writes the finished
  # ISO to ./out inside the checkout, which is also $REPO.
  rm -rf "$AIR/usr/share/archdots/out"

  # pacstrap cannot fetch from the AUR, so the installer needs the prebuilt
  # packages on the medium.
  mkdir -p "$AIR/usr/share/archdots/aur"
  cp "$AURREPO"/*.pkg.tar.zst "$AIR/usr/share/archdots/aur/"
  install -Dm755 "$REPO/installer/archdots-install" "$AIR/usr/local/bin/archdots-install"
  ok "installer + $(ls "$AURREPO"/*.pkg.tar.zst | wc -l) prebuilt AUR packages on the medium"

  cat > "$AIR/etc/skel/.bash_profile" <<'EOF'
[[ -f ~/.bashrc ]] && . ~/.bashrc
# Start the desktop only on the first VT, so other TTYs stay usable.
if [[ -z "${WAYLAND_DISPLAY:-}" && "${XDG_VTNR:-}" == 1 ]]; then
    exec start-hyprland
fi
EOF
  ok "config, .gtkrc-2.0 and a copy of the repo baked in"

  # mkarchiso copies airootfs with `cp -af --no-preserve=ownership,mode`, which
  # strips every executable bit. Without this, the Waybar modules and the Rofi
  # launchers all arrive as 0644: the battery widget renders nothing, and rofi
  # refuses to start because its nmap script mode is not executable.
  # profiledef's file_permissions is the archiso-native way to restore them.
  say "Restoring executable bits stripped by mkarchiso"
  {
    printf '\nfile_permissions+=(\n'
    while IFS= read -r f; do
      printf '  ["%s"]="0:0:755"\n' "${f#"$AIR"}"
    done < <(find "$AIR/etc/skel" "$AIR/usr/share/archdots" -type f -name '*.sh' | sort)
    # The installer has no .sh suffix, so it is listed explicitly.
    printf '  ["/usr/local/bin/archdots-install"]="0:0:755"\n'
    printf ')\n'
  } >> "$PROFILE/profiledef.sh"
  local n
  n=$(find "$AIR/etc/skel" "$AIR/usr/share/archdots" -type f -name '*.sh' | wc -l)
  ok "$n scripts marked 0755 via profiledef"
  find "$AIR/etc/skel" -type f -name '*.sh' -printf '       %P\n' | sort

  # GTK 4 and portal-aware apps read the theme from dconf, not settings.ini.
  # mkarchiso has no post-install hook, so the binary db is compiled here on
  # the host and shipped as a file rather than generated inside the image.
  say "Baking the Dracula GTK defaults into dconf"
  if command -v dconf >/dev/null; then
    install -Dm644 "$REPO/system/dconf/00-archdots-theme" \
      "$AIR/etc/dconf/db/local.d/00-archdots-theme"
    install -Dm644 "$REPO/system/dconf/profile-user" "$AIR/etc/dconf/profile/user"
    dconf compile "$AIR/etc/dconf/db/local" "$AIR/etc/dconf/db/local.d"
    ok "compiled /etc/dconf/db/local ($(stat -c%s "$AIR/etc/dconf/db/local") bytes)"
  else
    bad "dconf not installed on the host; GTK theme will need nwg-look at runtime"
  fi

  # A live user is required: Hyprland refuses to run as root, and releng
  # autologins root by default. useradd copies /etc/skel and fixes ownership,
  # which avoids needing recursive entries in profiledef's file_permissions.
  say "Creating the '$LIVEUSER' user at boot"
  mkdir -p "$AIR/etc/systemd/system"
  cat > "$AIR/etc/systemd/system/archdots-liveuser.service" <<EOF
[Unit]
Description=Create the archdots live user
After=systemd-remount-fs.service
Before=getty@tty1.service
ConditionPathExists=!/home/$LIVEUSER

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/useradd -m -G wheel,video,input,audio -s /bin/bash $LIVEUSER
# A real password, not 'passwd -d'. hyprlock.conf sets ignore_empty_input=true,
# so with an empty password the lock screen can never be dismissed: Enter
# submits nothing and the only way out is to kill the session.
ExecStart=/usr/bin/bash -c 'echo "$LIVEUSER:$LIVEPASS" | chpasswd'

[Install]
WantedBy=multi-user.target
EOF
  mkdir -p "$AIR/etc/systemd/system/multi-user.target.wants"
  ln -sf ../archdots-liveuser.service \
    "$AIR/etc/systemd/system/multi-user.target.wants/archdots-liveuser.service"

  mkdir -p "$AIR/etc/sudoers.d"
  printf '%%wheel ALL=(ALL:ALL) NOPASSWD: ALL\n' > "$AIR/etc/sudoers.d/00-archdots-wheel"

  say "Autologin as '$LIVEUSER' on tty1"
  mkdir -p "$AIR/etc/systemd/system/getty@tty1.service.d"
  cat > "$AIR/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --noreset --noclear --autologin $LIVEUSER - \${TERM}
EOF

  # releng wires up iwd + systemd-networkd; the archdots configs drive
  # NetworkManager (nmcli in the Rofi wifi menu, nmcli in the Waybar module),
  # and running both managers at once fights over the interfaces.
  say "Swapping iwd/systemd-networkd for NetworkManager"
  rm -f "$AIR/etc/systemd/system/multi-user.target.wants/iwd.service" \
        "$AIR/etc/systemd/system/multi-user.target.wants/systemd-networkd.service" \
        "$AIR/etc/systemd/system/sockets.target.wants/systemd-networkd.socket" \
        "$AIR/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service" \
        "$AIR/etc/systemd/system/dbus-org.freedesktop.network1.service"
  ln -sf /usr/lib/systemd/system/NetworkManager.service \
    "$AIR/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
  mkdir -p "$AIR/etc/systemd/system/network-online.target.wants"
  ln -sf /usr/lib/systemd/system/NetworkManager-wait-online.service \
    "$AIR/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service"
  ok "NetworkManager enabled"

  say "Branding the ISO"
  sed -i \
    -e 's/^iso_name=.*/iso_name="archdots"/' \
    -e 's|^iso_publisher=.*|iso_publisher="archdots"|' \
    -e 's|^iso_application=.*|iso_application="archdots live desktop"|' \
    -e 's/^iso_label=.*/iso_label="ARCHDOTS_$(date +%Y%m)"/' \
    "$PROFILE/profiledef.sh"
  printf 'archdots\n' > "$AIR/etc/hostname"
  # The lock screen asks for this, so it must not be a secret the user has to guess.
  cat > "$AIR/etc/motd" <<EOF

  archdots live
  user '$LIVEUSER', password '$LIVEPASS'  (also unlocks the hyprlock screen)

  To install to disk:  sudo archdots-install
  Preview first with:  sudo archdots-install --dry-run

EOF
  grep -E '^iso_(name|label|application)=' "$PROFILE/profiledef.sh" | sed 's/^/       /'
  ok "profile ready at $PROFILE"
}

# ------------------------------------------------------------------- build

cmd_build() {
  [ -d "$PROFILE" ] || { bad "No profile. Run: sudo $0 profile"; exit 1; }
  command -v mkarchiso >/dev/null || { bad "mkarchiso missing. Run: sudo $0 deps"; exit 1; }

  local avail
  avail=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
  info "free space on /: ${avail}G (the build needs roughly 10G transient)"
  [ "$avail" -lt 12 ] && bad "That is tight. Consider: sudo $HERE/vm.sh teardown"

  mkdir -p "$OUT"
  say "Running mkarchiso (15-30 minutes)"
  info "Log: $WORK/mkarchiso.log"
  if mkarchiso -v -w "$WORK/tmp" -o "$OUT" "$PROFILE" > "$WORK/mkarchiso.log" 2>&1; then
    ok "ISO built"
    ls -lh "$OUT"/*.iso | sed 's/^/       /'
    if [ -n "${SUDO_USER:-}" ]; then chown -R "$SUDO_USER" "$OUT"; fi
  else
    bad "mkarchiso failed; last 30 lines:"
    tail -30 "$WORK/mkarchiso.log" | sed 's/^/       /'
    exit 1
  fi
  rm -rf "$WORK/tmp"
}

cmd_all() { cmd_aurrepo; cmd_profile; cmd_build; }

# --------------------------------------------------------------------- run

cmd_run() {
  local ISO
  ISO=$(find "$OUT" -name '*.iso' 2>/dev/null | head -1)
  [ -n "$ISO" ] || { bad "No ISO in $OUT. Run: sudo $0 build"; exit 1; }

  if [ "$(id -u)" -eq 0 ]; then
    [ -n "${SUDO_USER:-}" ] || { bad "Run 'run' as your normal user."; exit 1; }
    say "Dropping back to $SUDO_USER (QEMU needs your Wayland session)"
    exec sudo -u "$SUDO_USER" "$0" run
  fi

  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    local s
    s=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-[0-9]*' ! -name '*.lock' \
         -printf '%f\n' 2>/dev/null | sort | head -1)
    [ -n "$s" ] && export WAYLAND_DISPLAY="$s"
  fi
  export GDK_BACKEND=wayland SDL_VIDEODRIVER=wayland

  local CODE=/usr/share/edk2/x64/OVMF_CODE.4m.fd
  [ -f "$CODE" ] || CODE=/usr/share/edk2/x64/OVMF_CODE.fd
  local VARS=/usr/share/edk2/x64/OVMF_VARS.4m.fd
  [ -f "$VARS" ] || VARS=/usr/share/edk2/x64/OVMF_VARS.fd
  # Writable NVRAM, so an installed system's UEFI boot entry survives a restart.
  local MYVARS="$OUT/OVMF_VARS.fd"
  [ -f "$MYVARS" ] || cp "$VARS" "$MYVARS"

  # VM_GL=off drops virgl entirely: the guest then has no hardware GL and mesa
  # falls back to llvmpipe, which does provide desktop OpenGL 4.5 in software.
  # Useful for telling "this app needs more GL than virgl offers" apart from
  # "this app is broken" -- kitty wants GL 3.3, hyprlock wants GLES plus
  # screencopy, and neither is satisfied by virgl here.
  local gfx=(-device virtio-vga-gl -display "${VM_DISPLAY:-gtk}",gl=on)
  if [ "${VM_GL:-on}" = "off" ]; then
    gfx=(-device virtio-vga -display "${VM_DISPLAY:-gtk}")
    info "GL disabled: guest will use llvmpipe (software, slow but complete)"
  fi

  # A blank disk to practise archdots-install against. Without one the live VM
  # has no installable target at all, so even --dry-run has nothing to name.
  # It appears in the guest as /dev/vda; the ISO itself is the CD, not a disk.
  local TESTDISK="$OUT/testdisk.img" disk=()
  if [ -n "${VM_DISK:-}" ] && [ ! -f "$TESTDISK" ]; then
    truncate -s "$VM_DISK" "$TESTDISK"
    info "created a blank $VM_DISK test disk: $TESTDISK"
  fi
  if [ -f "$TESTDISK" ]; then
    disk=(-drive file="$TESTDISK",if=virtio,format=raw,cache=writeback)
    info "test disk attached as /dev/vda ($(du -h "$TESTDISK" | cut -f1) used)"
  else
    info "no test disk; pass VM_DISK=20G to create one for archdots-install"
  fi

  # VM_BOOT=disk leaves the CD out so the machine boots whatever was installed
  # onto the test disk, which is how to check the installer's result.
  local media=(-cdrom "$ISO" -boot d)
  if [ "${VM_BOOT:-cd}" = "disk" ]; then
    [ -f "$TESTDISK" ] || { bad "No test disk to boot from."; exit 1; }
    media=()
    say "Booting the installed test disk (ISO not attached)"
  else
    say "Booting $(basename "$ISO")"
    info "Autologin as '$LIVEUSER' into Hyprland. Ctrl+Alt+G releases the mouse."
  fi
  echo
  qemu-system-x86_64 \
    -enable-kvm -machine q35,accel=kvm -cpu host -smp 4 -m 4096 \
    -drive if=pflash,format=raw,readonly=on,file="$CODE" \
    -drive if=pflash,format=raw,file="$MYVARS" \
    "${media[@]}" \
    "${disk[@]}" \
    "${gfx[@]}" \
    -device virtio-net-pci,netdev=n0 -netdev user,id=n0 \
    -device virtio-rng-pci -device virtio-tablet-pci -device virtio-keyboard-pci \
    -audiodev pipewire,id=snd0 -device ich9-intel-hda -device hda-output,audiodev=snd0 \
    -name "archdots live"
}

cmd_teardown() {
  say "Removing $WORK"
  rm -rf "$WORK"
  ok "removed"
  info "The nspawn container and the VM image were left alone."
}

case "${1:-}" in
  deps)     need_root deps;     cmd_deps ;;
  aurrepo)  need_root aurrepo;  cmd_aurrepo ;;
  profile)  need_root profile;  cmd_profile ;;
  build)    need_root build;    cmd_build ;;
  all)      need_root all;      cmd_all ;;
  run)      cmd_run ;;
  teardown) need_root teardown; cmd_teardown ;;
  *) sed -n '2,16p' "$0"; exit 2 ;;
esac
