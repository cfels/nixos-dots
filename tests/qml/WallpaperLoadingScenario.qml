import Quickshell
import QtQuick
import "moxi/panel"

ShellRoot {
	id: scenario
	property int step: 0
	property int waits: 0
	property var initialPaths: null

	WallpaperController {
		id: subject
	}

	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}

	Timer {
		interval: 30
		running: true
		repeat: true
		onTriggered: {
			try {
				scenario.check(++scenario.waits < 150, "Wallpaper loading timed out at step " + scenario.step)
				if (scenario.step === 0) {
					if (!subject.testScan.running || subject.testScan.cachedOnly)
						return
					scenario.check(subject.wallpapers.length === 2, "Gallery waits for expensive preview generation")
					scenario.check(subject.wallpaperPreview("/work/first.mp4") === "", "Cold cache already has generated previews")
					scenario.initialPaths = subject.wallpapers
					scenario.step++
				} else if (scenario.step === 1) {
					if (!subject.wallpaperPreview("/work/first.mp4"))
						return
					scenario.check(subject.testScan.running, "First preview waits for the complete scan")
					scenario.check(subject.wallpaperThumb("/work/first.mp4") === "/work/first.jpg", "Generated thumbnail missing")
					scenario.check(subject.wallpaperPreview("/work/second.mp4") === "", "Second preview finished too early")
					scenario.step++
				} else {
					if (subject.testScan.running || !subject.wallpaperPreview("/work/second.mp4"))
						return
					scenario.check(subject.wallpapers === scenario.initialPaths, "Preview enrichment recreated gallery delegates")
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
