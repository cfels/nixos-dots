import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import "moxi/panel"

ShellRoot {
	id: scenario

	property int step: 0

	function check(condition, message): void {
		if (!condition) throw new Error(message)
	}

	FakePlayer { id: fakePlayer }

	Window {
		id: testWindow
		visible: true
		width: 1000
		height: 600

		Item { id: host; x: 40; y: 50; width: 920; height: 420 }

		Panel {
			id: subject
			width: 1000
			height: 490
		}
	}

	property bool grabbing: false

	function capture(name): void {
		grabbing = true
		testWindow.contentItem.grabToImage(function(result) {
			if (!result.saveToFile("/work/panel-" + name + ".png")) {
				console.error("PANEL_SCENARIO_FAILED", "image capture failed")
				Qt.quit()
				return
			}
			scenario.step += 1
			scenario.grabbing = false
		})
	}

	Timer {
		interval: 650
		running: true
		repeat: true
		onTriggered: {
			if (scenario.grabbing) return
			var media = subject.testMedia
			var lyrics = subject.testLyrics
			try {
				if (scenario.step === 0) {
					media.emptyPhrases = ["Fixture idle"]
					subject.expanded = true
					scenario.step += 1
				} else if (scenario.step === 1) {
					scenario.capture("idle")
				} else if (scenario.step === 2) {
					media.player = fakePlayer
					scenario.step += 1
				} else if (scenario.step === 3) {
					scenario.capture("artwork")
				} else if (scenario.step === 4) {
					lyrics.lyricsFetchKey = lyrics.lyricsKey
					lyrics.applyLyrics(JSON.stringify({duration: 180, syncedLyrics: "[00:01]first line\n[00:02]second line\n[00:03]third line", plainLyrics: ""}))
					media.positionTrusted = true
					media.trackPosition = 2.2
					fakePlayer.position = 2.2
					scenario.step += 1
				} else if (scenario.step === 5) {
					scenario.capture("synced")
				} else if (scenario.step === 6) {
					lyrics.applyLyrics(JSON.stringify({duration: 180, syncedLyrics: "", plainLyrics: "plain first\nplain second"}))
					scenario.step += 1
				} else if (scenario.step === 7) {
					scenario.capture("plain")
				} else if (scenario.step === 8) {
					subject.surfaceHost = host
					scenario.step += 1
				} else if (scenario.step === 9) {
					scenario.capture("hosted")
				} else if (scenario.step === 10) {
					subject.surfaceHost = null
					subject.expanded = false
					scenario.step += 1
				} else if (scenario.step === 11) {
					scenario.capture("collapsed")
				} else {
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
