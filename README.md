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
| Hyprland | `hyprland.lua` — animations, window and layer rules, keybindings |
| Hyprpaper / Hyprlock / Hypridle | Wallpaper, lock screen, idle and suspend timers |
| Waybar | Workspaces and window title on the left; CPU, temperature, memory, disk, network, audio, headset battery, language, backlight, battery, clock and weather on the right |
| Rofi | App launcher, power menu, nmap scanner, Wi-Fi picker, clipboard history, QEMU VM launcher, Dracula theme |
| Kitty | Nerd Font, transparent background, Mocha and current-theme presets |
| Dunst | Notifications |
| Fish | Custom left and right prompt functions |
| GTK 2/3/4, Qt 6 | Dracula theme and font preferences, plus a dconf system default |
| nwg-displays / nwg-look | Monitor layout and GTK theme tooling |

The package lists are built from what the configs actually reference, not from
what happened to be installed on the source machine. Every entry in
[`packages/`](packages/) is called by something in `config/`, bar two pieces of
infrastructure flagged inline (`xdg-desktop-portal-hyprland` and `gvfs`). Only
`wttrbar` and `soteria-git` compile from source.

[`system/dconf/`](system/dconf/) holds the one piece that does not live under
`$HOME`: GTK 4 and portal-aware applications read the theme from dconf and
ignore `gtk-4.0/settings.ini`, so without it they stay unthemed until something
such as nwg-look writes the user's dconf by hand. `install.sh` installs it as a
*system* database, which needs no D-Bus session and still lets nwg-look
override per user.

Configs for tools nothing launches were removed rather than shipped inert, so
there is no Wofi, Wlogout, Swaylock, volumeicon, xsettingsd or Starship config
here even though the source machine had them.

Deliberately excluded: SSH keys and hosts, GPG, browser profiles, shell
history, clipboard history, nmap results, and application state for Chromium,
VS Code, FreeCAD, KiCad and OrcaSlicer.

## Machine-specific bits to review

This was captured from an Arch laptop (internal panel `eDP-1`, 1920x1200,
scale 1.333) that is sometimes docked to a 3440x1440@144 ultrawide. On new
hardware:

- **Monitors.** `config/hypr/hyprland.lua` uses a deliberately generic default
  (`output = ""`, `mode = "preferred"`, `position = "auto"`), which adapts to
  whatever is attached. If you want a fixed multi-monitor layout, run
  `nwg-displays` and copy its output in. `config/hypr/monitors.conf` and
  `docs/monitors.lua` are a previously captured dock layout, kept for
  reference — nothing sources them.
- **Waybar battery outline.** `config/waybar/modules/indicator-width.css` holds
  a pixel width computed for the display above — currently 1404px, sized for
  the laptop panel's 1440px logical width. Regenerate it with
  `config/waybar/modules/gen-indicator-width.sh` after changing monitors.
- **Legacy `.conf`.** [`docs/hyprland.conf.legacy`](docs/hyprland.conf.legacy)
  is the pre-Lua config, kept only for reference. Hyprland 0.57 cannot read it
  (see Versions), and it must not be placed in `~/.config/hypr/`.
- **Login.** No display manager is enabled; Hyprland is started with
  `start-hyprland` from a TTY.

## Dangling references

Some configs call programs the package lists deliberately leave out, to keep
the install lean. Each is inert until you install the program yourself, and the
rest of the desktop is unaffected.

| Referenced by | Needs | Effect while missing |
| --- | --- | --- |
| `waybar` interaction sound | `ffmpeg` | Bar clicks are silent |
| `waybar` weather and tray click actions | `chromium` | Clicks do nothing |
| `waybar/config.jsonc` `cava` module | `cava` | Audio visualiser is absent from the bar |
| `waybar` disk click action | `qdirstat` | Click does nothing |
| `waybar` audio click action | `pwvucontrol` | Click does nothing |
| `rofi/launchers/greenclip*` | `greenclip` | Launcher exits with no entries |
| `rofi/launchers/qemu-vm/` | `qemu-desktop`, `edk2-ovmf` | VM launcher cannot start a guest |

To restore any of them, add the package to `packages/pacman.txt` and re-run
`./install.sh --packages-only`.
| `swaylock/config` | a wallpaper not in this repo | Swaylock falls back to a solid colour |

## Versions

Running on Hyprland 0.57.0, Waybar 0.15.0, Arch Linux (kernel 7.2.11).
`config/hypr/hyprland.lua` passes `Hyprland --verify-config` and is the config
of a live 0.57.0 session, with Waybar, Hyprpaper, Hypridle, Dunst, the polkit
agent and the clipboard watchers all starting from it.

**Hyprland 0.57 reads `hyprland.lua` only.** It does not look at
`hyprland.conf` at all; if no `hyprland.lua` exists it writes an autogenerated
default and uses that. A legacy `.conf` is therefore silently ignored rather
than reported as an error, which makes the breakage easy to miss.

0.57 also lowered the maximum of `decoration.shadow.render_power` from 10 to 4,
and changed `hyprctl dispatch` to take a Lua expression instead of a dispatcher
name and arguments:

```sh
hyprctl dispatch exit 0               # 0.56 and earlier
hyprctl dispatch 'hl.dsp.exit()'      # 0.57
hyprctl dispatch 'hl.dsp.dpms("off")' # 0.57
```

Scripts and `hypridle.conf` are affected, not just `hyprland.lua`, and the old
form fails silently — the Logout entry in the Rofi power menu simply did
nothing. `hyprctl eval` runs a Lua string if you need to check a call, and
`hl.dsp` holds the dispatchers (`dpms` is `hl.dsp.dpms`, not `hl.dpms`).
`hyprctl switchxkblayout` is unaffected; it is a top-level command, not a
dispatch.

After upgrading Hyprland, check the config:

```sh
Hyprland --verify-config
```

Read the whole output, not just the verdict. Two traps:

- `No config file found; attempting to generate.` means your config was not
  loaded and `config ok` refers to a generated default.
- Passing an explicit `-c` always selects the Lua parser, so pointing it at a
  `.conf` reports spurious syntax errors. Run it with no arguments.

## Installing from the live ISO

The live medium carries `archdots-install`, which installs to a disk:

```sh
sudo archdots-install --dry-run   # print every step, change nothing
sudo archdots-install             # do it
```

It creates a GPT disk with a 512M ESP and a single ext4 root, pacstraps the
package set in [`packages/`](packages/) plus the kernel, firmware and the right
microcode, installs systemd-boot, creates your user, and then runs this repo's
own `install.sh` to link the configs. The result has `~/archdots` as a git
checkout symlinked into `~/.config`, so later edits show up as drift here.

It refuses to target the disk the live medium booted from, lists what it is
about to destroy, and asks for the disk path twice before touching anything.

The AUR packages are installed from prebuilt files carried on the medium, since
`pacstrap` cannot fetch from the AUR.

## Releases

[`.github/workflows/build-iso.yml`](.github/workflows/build-iso.yml) builds the
ISO on GitHub and attaches it to a release:

```sh
git tag v1.0.0 && git push origin v1.0.0
```

That produces `archdots-<date>-x86_64.iso` plus a `.sha256`, as release assets.
Running the workflow manually from the Actions tab instead gives a 7-day
artifact, or a dated prerelease if you tick the release box.

The build runs in a privileged `archlinux:base-devel` container on an Ubuntu
runner, so `actions/checkout` uses the host's Node and only `mkarchiso` needs
privileges. The AUR packages are compiled in CI with `AUR_METHOD=makepkg`,
which builds them as an unprivileged user in the container rather than relying
on the local nspawn rootfs that [`iso/build-iso.sh`](iso/build-iso.sh) prefers
when building by hand.

The runner's preinstalled .NET, Android and GHC toolchains are deleted first:
`mkarchiso` needs roughly 10 GB of scratch space and a default runner has about
14 GB free.

### Building the same ISO locally

```sh
sudo iso/build-iso.sh all   # aurrepo + profile + build
     iso/build-iso.sh run   # boot it in QEMU
```

`VM_DISK=20G iso/build-iso.sh run` attaches a blank disk so `archdots-install`
has a target, and `VM_BOOT=disk` then boots what was installed onto it.
`VM_GL=off` drops virgl so the guest falls back to llvmpipe, which is what
kitty and hyprlock need in a VM.
