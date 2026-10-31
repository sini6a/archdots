# archdots

My Hyprland desktop on Arch Linux, as a reproducible setup. Clone it into
`$HOME`, run the installer, and the graphical environment comes back.

Dracula-themed, with a Waybar whose battery indicator draws a rounded outline
around the whole bar, Rofi launchers for apps/power/nmap/QEMU, and Kitty + Fish
underneath.

## Install on a fresh system

```sh
cd ~
git clone <this-repo-url> archdots
cd archdots
./install.sh
```

That does two things:

1. Installs the packages in [`packages/`](packages/) with `pacman`, bootstraps
   `yay` if it is missing, then installs the AUR packages.
2. Symlinks every entry in `config/` into `~/.config/` and every dotfile in
   `home/` into `~`.

Anything already at a destination is **moved**, not deleted, into
`~/.archdots-backup/<timestamp>/`. Re-running is safe and idempotent.

Useful flags:

| Flag | Effect |
| --- | --- |
| `--dry-run` | Print every action, change nothing |
| `--no-packages` | Only link configs |
| `--packages-only` | Only install packages |

Because the configs are symlinks back into this repo, editing a config in
`~/.config/` edits the repo directly — `git status` here shows your drift, so
the backup never silently goes stale.

## What's included

| Component | Configuration |
| --- | --- |
| Hyprland | `hyprland.conf` — animations, window and layer rules, keybindings |
| Hyprpaper / Hyprlock / Hypridle | Wallpaper, lock screen, idle and suspend timers |
| Waybar | Workspaces and window title on the left; CPU, temperature, memory, disk, network, audio, headset battery, language, backlight, battery, clock and weather on the right |
| Rofi | App launcher, power menu, nmap scanner, Wi-Fi picker, clipboard history, QEMU VM launcher, Dracula theme |
| Wofi / Wlogout | Alternative launcher and the logout/shutdown menu |
| Kitty | Nerd Font, transparent background, Mocha and current-theme presets |
| Dunst | Notifications |
| Fish | Prompt functions and Starship config |
| GTK 2/3/4, Qt 6, xsettingsd | Dracula theme and font preferences |
| nwg-displays / nwg-look | Monitor layout and GTK theme tooling |
| Swaylock, volumeicon, hyfetch | Lock screen alternative, tray volume, fetch colours |

Deliberately excluded: SSH keys and hosts, GPG, browser profiles, shell
history, clipboard history, nmap results, and application state for Chromium,
VS Code, FreeCAD, KiCad and OrcaSlicer.

## Machine-specific bits to review

This was captured from a desktop with a 3440x1440@144 DP-1 primary and a
1080p HDMI secondary. On new hardware:

- **Monitors.** `config/hypr/hyprland.conf` has an inline `monitor =` line near
  the top. Run `nwg-displays` to get the right values and edit that line.
  `config/hypr/monitors.conf` and `monitors.lua` are nwg-displays output kept
  for reference — note that `hyprland.conf` does **not** source them.
- **Waybar battery outline.** `config/waybar/modules/indicator-width.css` holds
  a pixel width computed for the monitor above. Regenerate it with
  `config/waybar/modules/gen-indicator-width.sh` after changing monitors.
- **Swaylock.** `config/swaylock/config` points at a wallpaper path that is not
  in this repo. Hyprlock is what the keybindings actually use; fix or ignore.
- **Hyprland Lua config.** `config/hypr/hyprland.lua` is a complete port of the
  `.conf` to Hyprland's Lua API, kept as an alternative. The `.conf` is the live
  one and the two have drifted — treat the `.conf` as authoritative.
- **Login.** No display manager is enabled; Hyprland is started with
  `start-hyprland` from a TTY.

## Dangling references

These configs call programs that are not installed and are deliberately left
out of the package lists, because they are not installed on the source machine
either. Each is inert until you install the program yourself.

| Referenced by | Needs | Effect while missing |
| --- | --- | --- |
| `waybar/config.jsonc` `cava` module | `cava` | Audio visualiser is absent from the bar |
| `waybar` disk click action | `qdirstat` | Click does nothing |
| `waybar` audio click action | `pwvucontrol` | Click does nothing |
| `rofi/launchers/greenclip*` | `greenclip` | Launcher exits with no entries |
| `rofi/launchers/qemu-vm/` | `qemu-desktop`, `edk2-ovmf` | VM launcher cannot start a guest |
| `swaylock/config` | a wallpaper not in this repo | Swaylock falls back to a solid colour |

## Versions

Captured against Hyprland 0.56.2, Waybar 0.15.0, Arch Linux (kernel 7.1.9).
Hyprland moves fast and occasionally breaks config syntax between releases.
