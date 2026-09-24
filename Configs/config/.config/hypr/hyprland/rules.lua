----------------
--- RULES ------
----------------

-- extra -------------------------------------------------------------------------------

-- quickshell bar and panel
hl.layer_rule({
	match = { namespace = "quickshell" },
	blur = true,
	ignore_alpha = 0.2,
})

hl.window_rule({ match = { class = "kitty" }, tag = "+hyprglass_enabled" })
