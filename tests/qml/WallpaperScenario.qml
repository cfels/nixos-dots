import Quickshell
import Quickshell.Io
import QtQuick
import "moxi/panel"

ShellRoot {
	id: scenario

	property int step: 0
	property int attempts: 0
	readonly property string walls: Quickshell.env("HOME") + "/walls/"

	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}

	WallpaperController {
		id: subject
	}

	Process {
		id: changeFiles
	}

	Timer {
		interval: 100
		running: true
		repeat: true
		onTriggered: {
			try {
				scenario.attempts += 1
				scenario.check(scenario.attempts < 30, "wallpaper update timed out at step " + scenario.step)
				if (changeFiles.running)
					return
				if (scenario.step === 0) {
					if (subject.wallpapers.length !== 2)
						return
					scenario.check(subject.previewWallpaper === scenario.walls + "first.png", "initial selection")
					changeFiles.command = ["touch", scenario.walls + "dropped.png"]
				} else if (scenario.step === 1) {
					if (subject.wallpapers.indexOf(scenario.walls + "dropped.png") === -1)
						return
					scenario.check(!subject.expanded && subject.wallpapers.length === 3, "refresh while collapsed")
					scenario.check(subject.previewWallpaper === scenario.walls + "first.png", "addition preserves selection")
					subject.expanded = true
					changeFiles.command = ["mv", scenario.walls + "dropped.png", scenario.walls + "renamed.PNG"]
				} else if (scenario.step === 2) {
					if (subject.wallpapers.indexOf(scenario.walls + "renamed.PNG") === -1)
						return
					scenario.check(subject.wallpapers.length === 3 && subject.wallpapers.indexOf(scenario.walls + "dropped.png") === -1, "rename with unchanged file count")
					subject.previewWallpaper = scenario.walls + "renamed.PNG"
					subject.hoveredWallpaper = subject.previewWallpaper
					changeFiles.command = ["unlink", scenario.walls + "renamed.PNG"]
				} else if (scenario.step === 3) {
					if (subject.wallpapers.length !== 2)
						return
					scenario.check(subject.previewWallpaper === scenario.walls + "first.png", "removed selection falls back")
					scenario.check(subject.hoveredWallpaper === "", "removed hover clears")
					changeFiles.command = ["bash", "-c", "unlink \"$HOME/walls/first.png\" && unlink \"$HOME/walls/second.JPG\""]
				} else if (scenario.step === 4) {
					if (subject.wallpapers.length !== 0)
						return
					scenario.check(subject.previewWallpaper === "", "empty directory clears preview")
					changeFiles.command = ["bash", "-c", "touch /work/slow-wallpaper-scan \"$HOME/walls/queued-first.png\"; for attempt in {1..100}; do [[ -e /work/wallpaper-scan-started ]] && break; sleep 0.01; done; [[ -e /work/wallpaper-scan-started ]] || exit 1; touch \"$HOME/walls/queued-second.png\""]
				} else {
					if (subject.wallpapers.indexOf(scenario.walls + "queued-second.png") === -1)
						return
					scenario.check(subject.wallpapers.length === 2, "changes during a running scan are queued")
					console.log("PANEL_SCENARIO_OK")
					Qt.quit()
					return
				}
				changeFiles.running = true
				scenario.step += 1
				scenario.attempts = 0
			} catch (error) {
				console.error("PANEL_SCENARIO_FAILED", error)
				Qt.quit()
			}
		}
	}
}
