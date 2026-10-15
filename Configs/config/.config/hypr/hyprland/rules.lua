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

hl.window_rule({
	name = "dots-updater",
	match = { class = "moxi-updater" },
	tag = "+hyprglass_enabled",
	float = true,
	center = true,
	size = { "monitor_w * 0.65", "monitor_h * 0.7" },
})

hl.window_rule({
	name = "kde-file-picker",
	match = { class = "org.freedesktop.impl.portal.desktop.kde" },
	float = true,
	persistent_size = true,
})
