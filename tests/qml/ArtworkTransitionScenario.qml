import Quickshell
import QtQuick
import "moxi/panel"

ShellRoot {
	id: scenario
	property int step: 0
	property int ticks: 0
	property bool capturing: false

	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}

	function publish(source): void {
		state.artUnchanged = false
		state.artSourceKey = state.artCacheKey
		state.artSource = source
	}

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

	Window {
		visible: true
		width: 170
		height: 170
		color: "black"
		ArtworkView {
			id: view
			controller: state
		}
	}

	Timer {
		interval: 20
		running: true
		repeat: true
		onTriggered: {
			try {
				scenario.ticks++
				scenario.check(scenario.ticks < 180, "artwork timed out at step " + scenario.step)
				if (scenario.capturing)
					return
				if (scenario.step === 0) {
					media.player = fakePlayer
					scenario.publish("file:///work/image.svg")
					scenario.step = 1
				} else if (scenario.step === 1) {
					if (view.shown !== "file:///work/image.svg" || view.testSwap.running)
						return
					state.artFailed()
					scenario.check(view.ready && view.shown === "file:///work/image.svg", "a failed replacement must retain the previous cover")
					media.player = null
					scenario.check(view.ready, "a brief player metadata gap must not reveal the empty text")
					scenario.step = 2
					scenario.ticks = 0
				} else if (scenario.step === 2) {
					if (scenario.ticks < 4)
						return
					fakePlayer.trackTitle = "Track B"
					fakePlayer.metadata = ({
							"mpris:trackid": "B",
							"xesam:url": "file:///work/track-b"
						})
					media.player = fakePlayer
					scenario.publish("file:///work/corrected.svg")
					scenario.step = 3
					scenario.ticks = 0
				} else if (scenario.step === 3) {
					const incoming = view.testFirst.source === "file:///work/corrected.svg" ? view.testFirst : view.testSecond
					const outgoing = incoming === view.testFirst ? view.testSecond : view.testFirst
					if (!view.testSwap.running || incoming.x >= 140 || incoming.x <= 30)
						return
					view.testSwap.pause()
					scenario.check(view.testFirst.ready && view.testSecond.ready, "both decoded covers must be present during the slide")
					scenario.check(outgoing.source === "file:///work/image.svg" && incoming.source === "file:///work/corrected.svg", "outgoing and incoming covers must belong to their respective tracks")
					scenario.capturing = true
					view.grabToImage(result => {
						scenario.check(result.saveToFile("/work/panel-artwork-mid.png"), "artwork frame capture")
						view.testSwap.resume()
						scenario.capturing = false
						scenario.step = 4
					})
				} else if (scenario.step === 4) {
					if (view.shown !== "file:///work/corrected.svg" || view.testSwap.running)
						return
					scenario.check(view.ready && (view.testFirst.source === "" || view.testSecond.source === ""), "retire only the outgoing image after the slide")
					fakePlayer.trackTitle = "Track C"
					fakePlayer.metadata = ({
							"mpris:trackid": "C",
							"xesam:url": "file:///work/track-c"
						})
					scenario.publish("file:///work/missing-cover.svg")
					scenario.step = 5
					scenario.ticks = 0
				} else if (scenario.step === 5) {
					if (scenario.ticks < 5)
						return
					scenario.check(view.ready && view.shown === "file:///work/corrected.svg" && !view.testSwap.running, "a decode error must leave the current cover untouched")
					scenario.publish("file:///work/image.svg?v=rapid")
					scenario.publish("file:///work/tiny.svg")
					scenario.step = 6
					scenario.ticks = 0
				} else if (scenario.step === 6) {
					scenario.check(view.ready, "rapid replacements must not expose an empty frame")
					if (view.shown !== "file:///work/tiny.svg" || view.testSwap.running)
						return
					media.player = null
					scenario.step = 7
					scenario.ticks = 0
				} else if (scenario.step === 7) {
					if (scenario.ticks < 45)
						return
					scenario.check(!view.ready && view.shown === "", "genuine player disappearance must eventually restore the idle state")
					console.info("PANEL_SCENARIO_OK")
					Qt.quit()
				}
			} catch (error) {
				console.error("PANEL_SCENARIO_FAILED", error)
				Qt.quit()
			}
		}
	}
}
