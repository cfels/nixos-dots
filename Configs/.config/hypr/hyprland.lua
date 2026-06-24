-- stolen form end4
local HOME = os.getenv("HOME")

-- Environment variables --
require("hyprland.env")
require("hyprland.vars")
if HOME .. "/.config/hypr/custom/env.lua" then
end

-- default conf ----------------------------------------------------
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.colors")
require("hyprland.keybinds")
require("hyprland.input")
require("hyprland.looks")

if HOME .. "/.config/hyprland/execs.lua" then
	require("hyprland.execs")
end
if HOME .. "/.config/hyprland/general.lua" then
	require("hyprland.general")
end
if HOME .. "/.config/hyprland/rules.lua" then
	require("hyprland.rules")
end
if HOME .. "/.config/hyprland/keybinds.lua" then
	require("hyprland.keybinds")
end
if HOME .. "/.config/hyprland/input.lua" then
	require("hyprland.input")
end
if HOME .. "/.config/hyprland/looks.lua" then
	require("hyprland.looks")
end
if HOME .. "/.config/hyprland/vars.lua" then
	require("hyprland.vars")
end

-- displays ------------------------------------------------------
-- if HOME .. "/.config/hyprland/workspaces.lua" then
--	require("workspaces")
-- end

if HOME .. "/.config/hyprland/sonitor.lua" then
	require("hyprland.sonitor")
end
