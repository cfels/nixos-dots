----------------
--- RULES ------
----------------

-- extra -------------------------------------------------------------------------------

-- librewolf
hl.window_rule({ match = { class = "librewolf" }, no_blur = false })
hl.window_rule({
	match = { class = "librewolf" },
	opacity = "0.88 override 0.88 override 1.0 override",
})

-- emoji picker
hl.window_rule({ match = { class = "HyprEmoji" }, no_blur = false })
hl.window_rule({
	match = { class = "HyprEmoji" },
	opacity = "0.88 override 0.88 override 1.0 override",
})

-- hypremoji make it float

hl.window_rule({
	float = 1,
	match = {
		title = "^(HyprEmoji)$",
	},
})

hl.window_rule({
	move = "cursor -50% -5%",
	match = {
		title = "^(HyprEmoji)$",
	},
})

-- base -------------------------------------------------------------------------------

-- waybar
hl.layer_rule({ match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.5 })

-- swaync
hl.layer_rule({ match = { namespace = "swaync-control-center" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.5 })
