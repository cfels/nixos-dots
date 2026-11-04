import Quickshell
import QtQuick
import "components"

ShellRoot {
	id: scenario
	property int step: 0
	property int attempts: 0
	property int cycles: 0
	property int pausedTicks: 0
	property int pausedFrame: 0
	property size requestedSize: Qt.size(0, 0)
	property bool playing: true
	Window {
		visible: true
		width: 600
		height: 400
		SquircleImage {
			id: subject
			width: Math.max(0, scenario.requestedSize.width)
			height: Math.max(0, scenario.requestedSize.height)
			source: "file:///work/preview.gif"
			animated: true
			playing: scenario.playing
			sourceWidth: scenario.requestedSize.width
			sourceHeight: scenario.requestedSize.height
		}
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
				scenario.check(++scenario.attempts < 160, "Preview resizing timed out at step " + scenario.step)
				if (!subject.ready)
					return
				const movie = subject.testAnimation
				scenario.check(movie.sourceSize.width >= 1 && movie.sourceSize.height >= 1, "Animated decoder received empty dimensions")
				scenario.check(movie.frameCount > 1, "Preview lost animated frames")
				if (scenario.step === 0) {
					scenario.requestedSize = Qt.size(560, 316)
					scenario.step++
				} else if (scenario.step === 1) {
					if (movie.currentFrame === 0)
						return
					scenario.playing = false
					scenario.pausedFrame = movie.currentFrame
					scenario.pausedTicks = 0
					scenario.step++
				} else if (scenario.step === 2) {
					scenario.check(movie.currentFrame === scenario.pausedFrame, "Hidden preview kept playing")
					if (++scenario.pausedTicks < 3)
						return
					scenario.requestedSize = Qt.size(-24, 0)
					scenario.playing = true
					scenario.step++
				} else {
					if (++scenario.cycles < 5) {
						scenario.requestedSize = Qt.size(0, 0)
						scenario.step = 0
						return
					}
					console.log("WALLPAPER_PICKER_OK")
					Qt.quit()
				}
			} catch (error) {
				console.error("PICKER_FAILED", error)
				Qt.quit()
			}
		}
	}
}
