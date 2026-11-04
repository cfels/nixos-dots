require("hyprland.env")
require("hyprland.vars")
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.colors")
require("hyprland.keybinds")
require("hyprland.input")
require("hyprland.looks")
require("hyprland.sonitor")

-- User preferences are generated separately from the shipped compositor configuration.
local configHome = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local overridePath = configHome .. "/moxi/hyprland-overrides.lua"
local overrides = io.open(overridePath, "r")
if overrides then
	overrides:close()
	dofile(overridePath)
end
