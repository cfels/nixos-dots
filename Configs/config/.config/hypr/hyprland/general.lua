--------------------------------\
------------ GENERAL -----------\
--------------------------------\

local suppressMaximizeRule = hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },

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

-- window rule hypr dild
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move = "20 monitor_h-120",
	float = true,
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

----------------
----  MISC  ----
----------------

hl.config({
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = false,
	},
})
hl.config({
	dwindle = {
		preserve_split = true,
	},
})
hl.config({
	master = {
		new_status = "master",
	},
})
hl.config({
	scrolling = {
		fullscreen_on_one_column = true,
	},
})
