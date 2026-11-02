import Quickshell
import Quickshell.Io
import QtQuick
import "moxi/components"

ShellRoot {
	id: scenario

	property int step: 0
	property int attempts: 0

	Theme {
		id: subject
	}

	Process {
		id: writeColors
	}

	function writePalette(palette, atomic): void {
		writeColors.command = ["python3", "-c", "from pathlib import Path; import os,sys; path=Path(sys.argv[1]); target=path.with_suffix('.tmp') if sys.argv[3]=='1' else path; target.write_text(sys.argv[2]); os.replace(target,path) if target!=path else None", Quickshell.shellDir + "/colors.json", JSON.stringify(palette), atomic ? "1" : "0"]
		writeColors.running = true
		attempts = 0
	}

	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}

	Timer {
		interval: 50
		running: true
		repeat: true
		onTriggered: {
			try {
				scenario.attempts += 1
				scenario.check(scenario.attempts < 40, "theme update timed out at step " + scenario.step + "; accent=" + subject.accent)
				if (writeColors.running)
					return
				if (scenario.step === 0) {
					if (subject.palette.accent !== "#cba6f7")
						return
					scenario.writePalette({
						accent: "#112233",
						foreground: "#223344",
						background: "#334455"
					}, false)
					scenario.step = 1
				} else if (scenario.step === 1) {
					if ("" + subject.accent !== "#112233")
						return
					scenario.check("" + subject.foreground === "#223344" && "" + subject.background === "#334455", "palette properties did not update together")
					scenario.writePalette({
						accent: "#445566",
						foreground: "#667788"
					}, true)
					scenario.step = 2
				} else if (scenario.step === 2) {
					if ("" + subject.accent !== "#445566")
						return
					scenario.check("" + subject.foreground === "#667788", "atomic replacement left stale colors")
					scenario.writePalette({
						accent: "#778899"
					}, true)
					scenario.step = 3
				} else {
					if ("" + subject.accent !== "#778899")
						return
					console.log("PANEL_SCENARIO_OK")
					Qt.quit()
				}
			} catch (error) {
				console.error("PANEL_SCENARIO_FAILED", error)
				Qt.quit()
			}
		}
	}
}
