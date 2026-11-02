import Quickshell
import QtQuick
import "moxi/panel"

ShellRoot {
	id: scenario

	property int step: 0
	property string previousKey: ""
	property string previousSource: ""

	function check(condition, message): void {
		if (!condition) throw new Error(message)
	}

	FakePlayer {
		id: fakePlayer
		dbusName: "org.mpris.MediaPlayer2.chromium.instance1"
		metadata: ({"mpris:trackid": "A", "mpris:artUrl": "file:///work/image.svg"})
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
		interval: 350
		running: true
		repeat: true
		onTriggered: {
			try {
				var controller = subject.testArtwork
				var view = subject.testArtworkView
				if (scenario.step === 0) {
					subject.testMedia.player = fakePlayer
					subject.expanded = true
				} else if (scenario.step === 3) {
					scenario.check(controller.artVersion === 1, "initial browser cover is displayed")
					fakePlayer.trackTitle = "Song B"
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"mpris:trackid": "B"})
				} else if (scenario.step === 6) {
					scenario.check(controller.artVersion === 1, "browser temporarily reports the previous song's cover")
					scenario.previousKey = controller.artCacheKey
					scenario.previousSource = controller.artSource
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"mpris:artUrl": "file:///work/corrected.svg"})
				} else if (scenario.step === 9) {
					scenario.check(controller.artCacheKey !== scenario.previousKey, "corrected browser image has a separate cache entry")
					scenario.check(controller.artVersion === 2 && controller.artSource !== scenario.previousSource, "corrected browser cover replaces the stale cached cover")
					scenario.check(view.shown === controller.artSource, "corrected browser cover reaches the view")
					scenario.previousKey = controller.artCacheKey
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"mpris:trackid": "C"})
				} else if (scenario.step === 12) {
					scenario.check(controller.artCacheKey !== scenario.previousKey, "distinct browser recordings cannot share a cache entry just because their titles match")
					scenario.check(controller.artVersion === 2, "identical artwork is not republished")
					console.log("PANEL_SCENARIO_OK")
					Qt.quit()
				}
				scenario.step += 1
			} catch (error) {
				console.error("PANEL_SCENARIO_FAILED", error)
				Qt.quit()
			}
		}
	}
}
