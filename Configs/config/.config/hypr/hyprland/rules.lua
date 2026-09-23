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
