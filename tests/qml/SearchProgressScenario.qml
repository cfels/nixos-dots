import Quickshell
import QtQuick
import "moxi/panel"

ShellRoot {
	id: scenario

	property int step: 0
	property real pausedSweep: 0
	property real lastSweep: 0
	property bool returning: false

	function check(condition, message): void {
		if (!condition) throw new Error(message)
	}

	FakePlayer {
		id: fakePlayer
		trackTitle: ""
	}

	Window {
		visible: true
		width: 1000
		height: 600

		Panel {
			id: subject
			width: 1000
			height: 490
		}
	}

	Timer {
		interval: 20
		running: true
		repeat: true
		onTriggered: {
			try {
				var media = subject.testMedia
				var lyrics = subject.testLyrics
				var timeline = subject.testTimeline
				if (scenario.step === 0) {
					media.player = fakePlayer
					subject.expanded = true
					lyrics.lyricsWanted = true
				} else if (scenario.step === 30) {
					scenario.check(timeline.waiting && timeline.testSweep > 0.1, "search sweep has advanced")
					var before = timeline.testSweep
					lyrics.lyricsWanted = false
					lyrics.lyricsWanted = true
					scenario.check(Math.abs(timeline.testSweep - before) < 0.01, "lookup handoff preserves search position")
				} else if (scenario.step === 35) {
					scenario.pausedSweep = timeline.testSweep
					lyrics.lyricsWanted = false
				} else if (scenario.step === 40) {
					scenario.check(!timeline.waiting && Math.abs(timeline.testSweep - scenario.pausedSweep) < 0.01, "inactive lookup pauses the sweep")
					lyrics.lyricsWanted = true
					scenario.check(Math.abs(timeline.testSweep - scenario.pausedSweep) < 0.01, "resumed lookup keeps the sweep position")
				} else if (scenario.step === 45) {
					scenario.check(timeline.testSweep > scenario.pausedSweep, "resumed sweep continues moving")
					scenario.pausedSweep = timeline.testSweep
					timeline.dragging = true
				} else if (scenario.step === 50) {
					scenario.check(!timeline.waiting && Math.abs(timeline.testSweep - scenario.pausedSweep) < 0.01, "seeking pauses the sweep")
					timeline.dragging = false
					scenario.check(Math.abs(timeline.testSweep - scenario.pausedSweep) < 0.01, "ending a seek resumes without resetting the sweep")
				} else if (scenario.step === 115) {
					scenario.check(scenario.returning, "search sweep reverses smoothly at the far end")
					lyrics.lyricsWanted = false
				} else if (scenario.step === 140) {
					scenario.check(!timeline.waiting && timeline.waitingAmount < 0.01, "completed lookup hides the search segment")
					console.log("PANEL_SCENARIO_OK")
					Qt.quit()
				}
				if (scenario.step > 0 && scenario.step < 115) {
					scenario.check(Math.abs(timeline.testSweep - scenario.lastSweep) < 0.2, "search sweep does not jump between frames")
					if (timeline.waiting && timeline.testSweep < scenario.lastSweep - 0.001)
						scenario.returning = true
				}
				scenario.lastSweep = timeline.testSweep
				scenario.step += 1
			} catch (error) {
				console.error("PANEL_SCENARIO_FAILED", error)
				Qt.quit()
			}
		}
	}
}
