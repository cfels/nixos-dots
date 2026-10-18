import Quickshell
import QtQuick
import "moxi/panel"

ShellRoot {
	id: scenario

	property int step: 0

	function check(condition, message): void {
		if (!condition) throw new Error(message)
	}

	FakePlayer {
		id: fakePlayer
		metadata: ({"mpris:trackid": "A", "xesam:url": "file:///work/artwork-race", "mpris:artUrl": "file:///work/image.svg"})
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
				var media = subject.testMedia
				var controller = subject.testArtwork
				var view = subject.testArtworkView
				if (scenario.step === 0) {
					media.player = fakePlayer
					subject.expanded = true
				} else if (scenario.step === 1) {
					scenario.check(controller.artVersion === 0, "first artwork fetch is in flight")
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"mpris:artUrl": "file:///work/refresh.svg"})
				} else if (scenario.step === 6) {
					scenario.check(controller.artVersion === 1, "queued duplicate publishes only once")
					scenario.check(view.testTransitions === 1 && view.shown === controller.artSource, "queued duplicate slides only once")
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"mpris:artUrl": "file:///work/tiny.svg"})
				} else if (scenario.step === 10) {
					scenario.check(controller.artVersion === 2 && view.shown === controller.artSource, "same-track replacement is displayed")
					scenario.check(view.testTransitions === 1, "same-track replacement does not slide")
					fakePlayer.trackTitle = "Next"
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"xesam:url": "file:///work/next", "mpris:artUrl": "file:///work/image.svg"})
				} else if (scenario.step === 14) {
					scenario.check(view.testTransitions === 2 && view.shown === controller.artSource, "different track artwork still slides")
					fakePlayer.trackTitle = "Same cover"
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"xesam:url": "file:///work/same-cover"})
				} else if (scenario.step === 18) {
					scenario.check(controller.artVersion === 3 && view.testTransitions === 2, "different track with identical cover does not slide")
					fakePlayer.trackAlbum = "Updated Album"
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"mpris:artUrl": "file:///work/tiny.svg"})
				} else if (scenario.step === 22) {
					scenario.check(controller.artVersion === 4 && view.shown === controller.artSource, "late album metadata can refresh the cover")
					scenario.check(view.testTransitions === 2, "late album metadata does not swipe the same recording twice")
					fakePlayer.trackTitle = "Corrected title"
					fakePlayer.trackArtist = "Corrected artist"
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"mpris:artUrl": "file:///work/image.svg"})
				} else if (scenario.step === 26) {
					scenario.check(controller.artVersion === 5 && view.shown === controller.artSource, "corrected credits can refresh the cover")
					scenario.check(view.testTransitions === 2, "corrected credits do not swipe the same recording twice")
					fakePlayer.trackTitle = "Disco Floor #JerseyClub"
					fakePlayer.trackArtist = "Tai2Talented"
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"xesam:url": "https://music.youtube.com/watch?v=y3vo82HqL8A&list=LM", "mpris:artUrl": "file:///work/tiny.svg"})
				} else if (scenario.step === 30) {
					scenario.check(controller.artVersion === 6 && view.testTransitions === 3, "a different recording still slides")
					fakePlayer.trackAlbum = "Disco Floor #JerseyClub"
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"xesam:url": "https://www.youtube.com/watch?v=y3vo82HqL8A&list=another&index=4", "mpris:artUrl": "file:///work/image.svg"})
				} else if (scenario.step === 34) {
					scenario.check(controller.artVersion === 7 && view.shown === controller.artSource, "YouTube URL metadata can refresh the cover")
					scenario.check(view.testTransitions === 3, "YouTube playlist parameters do not swipe the same recording twice")
					fakePlayer.trackTitle = "No URL A"
					fakePlayer.metadata = ({"mpris:trackid": "A", "mpris:artUrl": "file:///work/tiny.svg"})
				} else if (scenario.step === 38) {
					scenario.check(controller.artVersion === 8 && view.testTransitions === 4, "recording without a URL still slides")
					fakePlayer.trackAlbum = "Late album without a URL"
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"mpris:artUrl": "file:///work/image.svg"})
				} else if (scenario.step === 42) {
					scenario.check(controller.artVersion === 9 && view.testTransitions === 4, "late album without a URL does not swipe twice")
					fakePlayer.trackTitle = "No URL B"
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"mpris:artUrl": "file:///work/tiny.svg"})
				} else if (scenario.step === 46) {
					scenario.check(controller.artVersion === 10 && view.testTransitions === 5, "different title without a URL still slides with a constant MPRIS track ID")
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
