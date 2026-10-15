-- stolen form end4
local HOME = os.getenv("HOME")

-- Environment variables --
require("hyprland.env")
require("hyprland.vars")

-- default conf ----------------------------------------------------
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.colors")
require("hyprland.keybinds")
require("hyprland.input")
require("hyprland.looks")

-- execs
if HOME .. "/.config/hyprland/execs.lua" then
	require("hyprland.execs")
end

-- general conf
if HOME .. "/.config/hyprland/general.lua" then
	require("hyprland.general")
end

-- window rules etc.
if HOME .. "/.config/hyprland/rules.lua" then
	require("hyprland.rules")
end

-- keybinds
if HOME .. "/.config/hyprland/keybinds.lua" then
	require("hyprland.keybinds")
end

-- input stuff
if HOME .. "/.config/hyprland/input.lua" then
	require("hyprland.input")
end

-- looks
if HOME .. "/.config/hyprland/looks.lua" then
	require("hyprland.looks")
end

-- vars
if HOME .. "/.config/hyprland/vars.lua" then
	require("hyprland.vars")
end

-- displays

if HOME .. "/.config/hyprland/sonitor.lua" then
	require("hyprland.sonitor")
end
