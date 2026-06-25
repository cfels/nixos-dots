-------------------------------\
------------ EXECS ------------\
-------------------------------\

hl.on("hyprland.start", function()
	-- exec aww daemon
	hl.exec_cmd("bash -c '$HOME/.local/bin/wall'")

	--  set Cursor
	hl.exec_cmd("bash -c '$HOME/.local/bin/applycursor'")
end)
