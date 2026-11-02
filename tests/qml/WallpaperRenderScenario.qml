import Quickshell
import QtQuick
import QtQuick.Window
import "wallpaper"

ShellRoot {
	id: scenario

	property int step: 0
	property int corner: 0
	property int attempts: 0
	property bool capturing: false
	property string target: ""
	property bool expectOutgoing: false
	property bool expectIncoming: false
	property int oldMin: -1
	property int oldMax: -1
	property int newMin: -1
	property int newMax: -1

	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}

	function ready(path): bool {
		return canvas.phase === "ready" && canvas.currentPath === path
	}

	function load(path, nextStep, outgoing, incoming): void {
		target = path
		expectOutgoing = outgoing
		expectIncoming = incoming
		oldMin = -1
		oldMax = -1
		newMin = -1
		newMax = -1
		attempts = 0
		step = nextStep
		canvas.setWallpaper(path, corner)
	}

	function mediaFinished(): bool {
		if (canvas.phase === "animating") {
			const oldPosition = canvas.current.position
			const newPosition = canvas.incoming.position
			oldMin = oldMin < 0 ? oldPosition : Math.min(oldMin, oldPosition)
			oldMax = Math.max(oldMax, oldPosition)
			newMin = newMin < 0 ? newPosition : Math.min(newMin, newPosition)
			newMax = Math.max(newMax, newPosition)
		}
		if (!ready(target))
			return false
		check(!expectOutgoing || oldMax - oldMin >= 30, "outgoing video stopped during reveal at step " + step)
		check(!expectIncoming || newMax - newMin >= 30, "incoming video did not play during reveal at step " + step)
		check(canvas.incoming.path === "", "outgoing decoder retained after reveal")
		return true
	}

	Window {
		visible: true
		width: 320
		height: 180
		color: "black"

		WallpaperCanvas {
			id: canvas
			anchors.fill: parent
			Component.onCompleted: setWallpaper("/work/red.png", 0)
		}
	}

	Timer {
		interval: 20
		repeat: true
		running: true
		onTriggered: {
			try {
				scenario.attempts += 1
				scenario.check(scenario.attempts < 450, "timed out at step " + scenario.step)
				if (scenario.step === 0) {
					if (!scenario.ready("/work/red.png"))
						return
					canvas.setWallpaper("/work/blue.png", scenario.corner)
					scenario.step = 1
				} else if (scenario.step === 1) {
					if (canvas.phase !== "animating")
						return
					canvas.testReveal.pause()
					canvas.progress = 0.35
					scenario.attempts = 0
					scenario.step = 2
				} else if (scenario.step === 2) {
					if (scenario.attempts < 3 || scenario.capturing)
						return
					scenario.capturing = true
					canvas.grabToImage(result => {
						result.saveToFile("/work/grow-" + scenario.corner + ".png")
						canvas.testReveal.resume()
						scenario.capturing = false
						scenario.step = 3
					})
				} else if (scenario.step === 3) {
					if (!scenario.ready("/work/blue.png"))
						return
					if (scenario.corner === 3) {
						scenario.load("/work/video.mp4", 5, false, true)
					} else {
						canvas.setWallpaper("/work/red.png", 0)
						scenario.step = 4
					}
				} else if (scenario.step === 4) {
					if (!scenario.ready("/work/red.png"))
						return
					scenario.corner += 1
					canvas.setWallpaper("/work/blue.png", scenario.corner)
					scenario.step = 1
				} else if (scenario.step === 5) {
					if (canvas.phase !== "animating")
						return
					canvas.testReveal.pause()
					canvas.progress = 0.35
					scenario.attempts = 0
					scenario.step = 15
				} else if (scenario.step === 15) {
					if (scenario.attempts < 3 || scenario.capturing)
						return
					scenario.capturing = true
					canvas.grabToImage(result => {
						result.saveToFile("/work/grow-video.png")
						canvas.testReveal.resume()
						scenario.capturing = false
						scenario.step = 6
					})
				} else if (scenario.step === 6) {
					if (!scenario.mediaFinished())
						return
					scenario.load("/work/red.jpg", 7, true, false)
				} else if (scenario.step === 7) {
					if (!scenario.mediaFinished())
						return
					scenario.corner = 0
					scenario.load("/work/video.mp4", 16, false, true)
				} else if (scenario.step === 16) {
					if (canvas.phase !== "animating")
						return
					canvas.testReveal.pause()
					canvas.progress = 0.35
					scenario.attempts = 0
					scenario.step = 17
				} else if (scenario.step === 17) {
					if (scenario.attempts < 3 || scenario.capturing)
						return
					scenario.capturing = true
					canvas.grabToImage(result => {
						result.saveToFile("/work/grow-jpg-video.png")
						canvas.testReveal.resume()
						scenario.capturing = false
						scenario.step = 8
					})
				} else if (scenario.step === 8) {
					if (!scenario.mediaFinished())
						return
					scenario.load("/work/second.mp4", 9, true, true)
				} else if (scenario.step === 9) {
					if (!scenario.mediaFinished())
						return
					scenario.load("/work/animated.gif", 10, true, false)
				} else if (scenario.step === 10) {
					if (!scenario.mediaFinished())
						return
					canvas.setWallpaper("/work/bad.png", 0)
					scenario.step = 11
				} else if (scenario.step === 11) {
					if (canvas.phase !== "failed")
						return
					scenario.check(canvas.currentPath === "/work/animated.gif", "failed load replaced current wallpaper")
					canvas.setWallpaper("/work/animated.gif", 0)
					scenario.check(canvas.phase === "ready" && canvas.error === "", "same-wallpaper retry did not clear failure")
					canvas.setWallpaper("/work/red.png", 0)
					canvas.setWallpaper("/work/video.mp4", 1)
					canvas.setWallpaper("/work/blue.png", 2)
					scenario.step = 12
				} else if (scenario.step === 12) {
					if (!scenario.ready("/work/blue.png"))
						return
					scenario.check(canvas.pendingPath === "" && canvas.incoming.path === "", "queued transition retained media")
					console.log("WALLPAPER_RENDER_OK")
					Qt.quit()
				}
			} catch (error) {
				console.error("SCENARIO_FAILED", error)
				Qt.quit()
			}
		}
	}
}
