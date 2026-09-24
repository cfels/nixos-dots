-------------------------------\
------------ EXECS ------------\
-------------------------------\

hl.on("hyprland.start", function()
	-- exec aww daemon
	hl.exec_cmd("bash -c '$HOME/.local/bin/wall'")

	--  set Cursor
	hl.exec_cmd("bash -c '$HOME/.local/bin/applycursor'")

	-- clipboard history
	hl.exec_cmd("bash -c 'wl-paste --watch cliphist store'")

	hl.exec_cmd("$HOME/.config/hypr/scripts/quickshell-reload.sh")
end)
