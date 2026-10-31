-- Migrated from hyprland.conf for Hyprland 0.56.2.
-- The original .conf is retained as a backup. Restart Hyprland to switch formats.
-- API reference: /usr/share/hypr/stubs/hl.meta.lua

-- Programs
local terminal = "kitty"
local fileManager = "thunar"
local menu = "rofi -no-lazy-grab -show drun"
local powerMenu = "~/.config/rofi/launchers/power-menu.sh"
local nmap = "~/.config/rofi/launchers/nmap.sh"
local cliphist = "cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy"
local mainMod = "SUPER"

-- Monitor geometry
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.33 })

-- Environment
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Start programs only when the session starts, never on config reload.
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar & hyprpaper &")
    hl.exec_cmd("/usr/lib/soteria-polkit/soteria &")
    hl.exec_cmd("hypridle &")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- Appearance, layout and input
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 16,
        border_size = 2,
        col = {
            active_border = "rgba(bd93f9cc)",
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 6,
        rounding_power = 3,
        active_opacity = 1.0,
        inactive_opacity = 0.9,
        shadow = {
            enabled = true,
            range = 10,
            render_power = 10,
            color = "rgba(1a1a1a30)",
        },
        blur = {
            enabled = true,
            size = 10,
            passes = 3,
            xray = true,
            popups = true,
            special = true,
            vibrancy = 0.1696,
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
    input = {
        kb_layout = "se,mk",
        kb_variant = "",
        kb_model = "",
        kb_options = "grp:win_space_toggle",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
            scroll_factor = 0.20,
        },
    },
})

-- Layer backgrounds
hl.layer_rule({
    name = "blur-rofi",
    match = {
        namespace = "rofi",
    },
    blur = true,
    ignore_alpha = 0,
})
hl.layer_rule({
    name = "blur-waybar",
    match = {
        namespace = "waybar",
    },
    blur = true,
    ignore_alpha = 0,
})

-- Animation curves (last definition wins, as in the original config)
hl.curve("wind", { type = "bezier", points = { {0.05, 0.85}, {0.03, 0.97} } })
hl.curve("winIn", { type = "bezier", points = { {0.07, 0.88}, {0.04, 0.99} } })
hl.curve("winOut", { type = "bezier", points = { {0.20, -0.15}, {0, 1} } })
hl.curve("liner", { type = "bezier", points = { {1, 1}, {1, 1} } })
hl.curve("md3_standard", { type = "bezier", points = { {0.12, 0}, {0, 1} } })
hl.curve("md3_decel", { type = "bezier", points = { {0.05, 0.80}, {0.10, 0.97} } })
hl.curve("md3_accel", { type = "bezier", points = { {0.20, 0}, {0.80, 0.08} } })
hl.curve("overshot", { type = "bezier", points = { {0.05, 0.85}, {0.07, 1.04} } })
hl.curve("crazyshot", { type = "bezier", points = { {0.1, 1.22}, {0.68, 0.98} } })
hl.curve("hyprnostretch", { type = "bezier", points = { {0.05, 0.82}, {0.03, 0.94} } })
hl.curve("menu_decel", { type = "bezier", points = { {0.05, 0.82}, {0, 1} } })
hl.curve("menu_accel", { type = "bezier", points = { {0.20, 0}, {0.82, 0.10} } })
hl.curve("easeInOutCirc", { type = "bezier", points = { {0.78, 0}, {0.15, 1} } })
hl.curve("easeOutCirc", { type = "bezier", points = { {0, 0.48}, {0.38, 1} } })
hl.curve("easeOutExpo", { type = "bezier", points = { {0.10, 0.94}, {0.23, 0.98} } })
hl.curve("softAcDecel", { type = "bezier", points = { {0.20, 0.20}, {0.15, 1} } })
hl.curve("md2", { type = "bezier", points = { {0.30, 0}, {0.15, 1} } })
hl.curve("OutBack", { type = "bezier", points = { {0.28, 1.40}, {0.58, 1} } })

-- Animations
hl.animation({ leaf = "border", enabled = true, speed = 1.6, bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 82, bezier = "liner", style = "loop" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.2, bezier = "winIn", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.8, bezier = "easeOutCirc" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.0, bezier = "wind", style = "slide" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.8, bezier = "md3_decel" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 1.8, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "menu_accel" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.6, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.8, bezier = "menu_accel" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4.0, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.3, bezier = "md3_decel", style = "slidefadevert 15%" })

-- Gestures and device overrides
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})
hl.device({
    name = "usb-optical-mouse",
    sensitivity = -1,
})

-- Keybindings
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd(powerMenu))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { repeating = true, locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { repeating = true, locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd(cliphist))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("killall -SIGUSR1 waybar || waybar"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Window rules
-- Preserve the effective final title matcher in thunar-popup-float.
-- The old config assigned match:title twice, so File Operation Progress won.
hl.window_rule({
    name = "thunar-popup-float",
    match = {
        title = "File Operation Progress",
    },
    float = true,
})
hl.window_rule({
    name = "suppress-maximize-events",
    match = {
        class = ".*",
    },
    suppress_event = "maximize",
})
hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})
hl.window_rule({
    name = "move-hyprland-run",
    match = {
        class = "hyprland-run",
    },
    move = "20 monitor_h-120",
    float = true,
})
hl.window_rule({
    name = "fix-kitty-scroll",
    match = {
        class = "kitty",
    },
    scroll_touchpad = 1,
})
