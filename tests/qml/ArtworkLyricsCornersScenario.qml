import Quickshell
import QtQuick
import "moxi/panel"

ShellRoot {
	id: scenario
	property int step: 0
	property int ticks: 0
	property bool capturing: false
	readonly property var fades: [0, 1, 0.8, 0.5, 0.2, 0.02, 0, 1, 0.5, 0]

	FakePlayer {
		id: fakePlayer
	}
	PlayerController {
		id: media
	}
	ArtworkController {
		id: state
		media: media
	}
	LyricsController {
		id: lyrics
		media: media
	}

	Window {
		id: testWindow
		visible: true
		width: 170
		height: 170
		color: "black"
		ArtworkView {
			id: view
			controller: state
			scale: 1
			lyricsFade: lyrics.lyricsFade
			lyricsBlur: lyrics.lyricsBlur
		}
	}

	Timer {
		interval: 60
		running: true
		repeat: true
		onTriggered: {
			if (scenario.capturing)
				return
			if (++scenario.ticks > 100) {
				console.error("PANEL_SCENARIO_FAILED", "lyrics corner test timed out")
				Qt.quit()
				return
			}
			if (scenario.step === 0) {
				media.player = fakePlayer
				state.artSourceKey = state.artCacheKey
				state.artSource = "file:///work/image.svg"
				scenario.step++
			} else if (scenario.step === 1) {
				if (!view.ready || view.testSwap.running)
					return
				scenario.step++
			} else {
				const index = Math.floor((scenario.step - 2) / 2)
				if (index === scenario.fades.length) {
					console.info("PANEL_SCENARIO_OK")
					Qt.quit()
					return
				}
				if (scenario.step % 2 === 0) {
					// Hold representative frames of the controller's return from lyrics.
					lyrics.lyricsMix = scenario.fades[index]
					scenario.step++
					return
				}
				if (Math.abs(lyrics.lyricsMix - scenario.fades[index]) > 0.001)
					return
				scenario.capturing = true
				testWindow.contentItem.grabToImage(result => {
					if (!result.saveToFile("/work/panel-corners-" + index + ".png"))
						console.error("PANEL_SCENARIO_FAILED", "corner frame capture failed")
					scenario.capturing = false
					scenario.step++
				})
			}
		}
	}
}
