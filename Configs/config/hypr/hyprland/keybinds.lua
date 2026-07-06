---------------------------------\
------------ KEYBINDS -----------\
---------------------------------\

-- programiczkus --------------
local terminal = "kitty"
local fileManager = "dolphin"
local menu = "rofi -show drun"
local browser = "librewolf"
local lockapp = "hyprlock"
local logout = "wlogout"
local mojis = "hypremoji"

-- your "windows" key
local SUPER = "SUPER"

-- autostart
hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
	hl.exec_cmd("swaync")
end)

-- screenshoting and clearing clipboard
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("cliphist wipe && wl-copy --clear"))
--screenshot
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -z -o ~/scrnsht"))
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m output --current -o ~/scrnsht"))

-- emojis
hl.bind(SUPER .. " + period", hl.dsp.exec_cmd(mojis))

-- lockscreen and logout
hl.bind(SUPER .. " + SHIFT + L", hl.dsp.exec_cmd(lockapp))
hl.bind(SUPER .. " + SHIFT + P", hl.dsp.exec_cmd(logout))

-- reload waybar and swaync
hl.bind(SUPER .. " + SHIFT + R", function()
	hl.exec_cmd("pkill waybar; waybar")
	hl.exec_cmd("swaync-client -R && swaync-client -rs")
end)

-- close program
local closeWindowBind = hl.bind(SUPER .. " + Q", hl.dsp.window.close())

-- SHUTDOWN HYPRLAND ig
hl.bind(
	"SUPER + SHIFT + M",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)

-- window stuff
hl.bind(SUPER .. " + SHIFT + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(SUPER .. " + J", hl.dsp.layout("togglesplit")) -- basically splits or smth like that

-- apps
hl.bind(SUPER .. " + W", hl.dsp.exec_cmd(browser))
hl.bind(SUPER .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(SUPER .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(SUPER .. " + RETURN", hl.dsp.exec_cmd(terminal))

-- move focus to diff window
hl.bind(SUPER .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(SUPER .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(SUPER .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(SUPER .. " + down", hl.dsp.focus({ direction = "down" }))

-- fullscreen and maximize
hl.bind(
	"SUPER + F",
	hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
	{ description = "Window: Maximize" }
)
hl.bind(
	"SUPER + SHIFT + F",
	hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
	{ description = "Window: Fullscreen" }
)

-- window switching shit
for i = 1, 4 do
	local key = { "SUPER + ALT + Page_", "CTRL + SUPER + SHIFT + " }
	local keycombos = { key[1] .. "down", key[1] .. "up", key[2] .. "Right", key[2] .. "Left" }
	local prefix = { "r+", "r-", "r+", "r-" }
	hl.bind(keycombos[i], hl.dsp.window.move({ workspace = prefix[i] .. "1" })) -- # [hidden]
end

--#/# bind = SUPER + SHIFT, ←/↑/→/↓,, -- Move in direction
for i = 1, 4 do
	local arrowkey = { "Left", "Right", "Up", "Down" }
	local focusdir = { "l", "r", "u", "d" }
	hl.bind("SUPER + SHIFT + " .. arrowkey[i], hl.dsp.window.move({ direction = focusdir[i] }))
end

-- switch workspaces
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(SUPER .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(SUPER .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- idk
hl.bind(SUPER .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(SUPER .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- move resize
hl.bind(SUPER .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(SUPER .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- needed ig
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
