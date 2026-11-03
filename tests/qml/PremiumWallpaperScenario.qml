import Quickshell
import QtQuick
import QtQuick.Window
import Quickshell.Io
import "wallpaper"

ShellRoot {
	id: scenario
	property int step: 0
	property int attempts: 0
	property int loops: 0
	property int previousPosition: 0
	property int pausedPosition: 0
	property real pausedEffects: 0

	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}

	Window {
		width: 640
		height: 360
		visible: true
		color: "magenta"
		Loader {
			id: loader
			anchors.fill: parent
			sourceComponent: WallpaperCanvas {
				outputName: "DP-1"
				Component.onCompleted: setWallpaper("/work/Velina.premiumwall.json", 0)
			}
		}
	}

	FileView {
		id: fixture
		path: "/work/Velina.premiumwall.json"
		blockLoading: true
		blockWrites: true
	}

	Timer {
		interval: 20
		repeat: true
		running: true
		onTriggered: {
			try {
				scenario.attempts++
				scenario.check(scenario.attempts < 700, "timed out at step " + scenario.step)
				const subject = loader.item ? loader.item.current.premiumPlayer : null
				if (subject)
					scenario.check(subject.error.length === 0, subject.error)
				if (scenario.step === 0) {
					if (!subject || subject.playbackState !== "OPENING")
						return
					scenario.check(subject.useOpening && subject.startupSound, "first load reserves opening and audio")
					scenario.check(subject.openingVideo.player.hasAudio, "opening retains its audio stream")
					scenario.step = 1
				} else if (scenario.step === 1) {
					if (subject.playbackState !== "SHOWCASE_LOOP")
						return
					scenario.check(subject.showcaseDisplayed && subject.openingRetired && subject.openingVideo === null, "handoff displays prepared showcase and releases opening decoder")
					scenario.previousPosition = subject.position
					scenario.step = 2
				} else if (scenario.step === 2) {
					if (subject.position < scenario.previousPosition)
						scenario.loops++
					scenario.previousPosition = subject.position
					if (scenario.loops < 3)
						return
					subject.suspended = true
					scenario.check(subject.playbackState === "PAUSED", "fullscreen pauses controller")
					scenario.pausedPosition = subject.position
					scenario.attempts = 0
					scenario.step = 3
				} else if (scenario.step === 3) {
					if (scenario.attempts < 12)
						return
					scenario.check(Math.abs(subject.position - scenario.pausedPosition) < 50, "paused video remains stationary")
					subject.suspended = false
					scenario.check(subject.playbackState === "SHOWCASE_LOOP", "resume preserves showcase phase")
					loader.active = false
					scenario.step = 4
				} else if (scenario.step === 4) {
					loader.active = true
					scenario.step = 5
				} else if (scenario.step === 5) {
					if (!subject || subject.playbackState !== "SHOWCASE_LOOP")
						return
					scenario.check(!subject.useOpening && !subject.startupSound, "component reload must not replay opening or sound")
					const settings = JSON.parse(fixture.text())
					settings.loop = false
					settings.startupAudio = false
					settings.effectsQuality = "off"
					fixture.setText(JSON.stringify(settings))
					scenario.step = 6
				} else if (scenario.step === 6) {
					if (subject.config.effectsQuality !== "off" || subject.playbackState !== "PAUSED")
						return
					scenario.check(subject.completed && !subject.config.loop, "live settings disable looping and effects")
					subject.suspended = true
					subject.suspended = false
					scenario.check(subject.playbackState === "PAUSED", "completed one-shot stays complete after fullscreen")
					const settings = JSON.parse(fixture.text())
					settings.loop = true
					fixture.setText(JSON.stringify(settings))
					scenario.step = 7
				} else if (scenario.step === 7) {
					if (subject.playbackState !== "SHOWCASE_LOOP" || subject.position < 30)
						return
					scenario.check(!subject.completed && subject.config.loop, "enabling looping resumes a completed showcase")
					console.info("PREMIUM_WALLPAPER_OK")
					Qt.quit()
				}
			} catch (error) {
				console.error("SCENARIO_FAILED", error)
				Qt.exit(1)
			}
		}
	}
}
