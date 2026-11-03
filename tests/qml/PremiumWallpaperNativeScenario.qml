import Quickshell
import QtQuick
import QtQuick.Window
import "wallpaper"

ShellRoot {
	id: root
	readonly property bool captureEnabled: Quickshell.env("MOXI_NATIVE_CAPTURE") !== "0"
	property var live: canvas.current.premiumPlayer
	property real lastFrame: 0
	property int maxFrameGap: 0
	property int frames: 0
	property var slowFrames: []
	property int screenshots: 0
	property bool capturedOpening: false
	property bool capturedShowcase: false
	function capture(name) {
		if (!captureEnabled)
			return
		canvas.grabToImage(result => result.saveToFile("/work/" + name + ".png"), Qt.size(960, 540))
	}
	Window {
		visible: true
		width: 960
		height: 540
		color: "magenta"
		WallpaperCanvas {
			id: canvas
			anchors.fill: parent
			outputName: "DP-native-check"
			Component.onCompleted: setWallpaper("/work/Velina.premiumwall.json", 0)
		}
	}
	Connections {
		target: root.live ? root.live.showcaseVideo : null
		function onPresented() {
			if (!root.live || root.live.playbackState !== "SHOWCASE_LOOP")
				return
			const now = Date.now()
			if (root.lastFrame > 0) {
				root.maxFrameGap = Math.max(root.maxFrameGap, now - root.lastFrame)
				if (now - root.lastFrame > 70)
					root.slowFrames = root.slowFrames.concat([
						{
							gap: now - root.lastFrame,
							loop: root.live.loopCount,
							position: root.live.position
						}
					])
			}
			root.lastFrame = now
			root.frames++
		}
	}
	Timer {
		interval: 100
		repeat: true
		running: true
		onTriggered: {
			if (!root.live)
				return
			if (root.live.error.length > 0) {
				console.error("NATIVE_FAILED", root.live.error)
				Qt.quit()
			}
			if (root.live.playbackState === "OPENING" && root.live.position >= 3200 && !root.capturedOpening) {
				root.capturedOpening = true
				root.capture("native-opening")
			}
			if (root.live.playbackState === "SHOWCASE_LOOP" && !root.capturedShowcase) {
				root.capturedShowcase = true
				root.capture("native-showcase")
			}
			if (root.live.playbackState === "SHOWCASE_LOOP" && root.screenshots < 5) {
				root.capture("native-sample-" + root.screenshots)
				root.screenshots++
			}
			if (root.live.loopCount >= 3) {
				console.info("NATIVE_OK", JSON.stringify({
					frames: root.frames,
					capturesEnabled: root.captureEnabled,
					maxFrameGapMs: root.maxFrameGap,
					slowFrames: root.slowFrames,
					loops: root.live.loopCount,
					openingRetired: root.live.openingRetired,
					capturedOpening: root.capturedOpening
				}))
				Qt.quit()
			}
		}
	}
	Timer {
		interval: 32000
		running: true
		onTriggered: {
			console.error("NATIVE_TIMEOUT")
			Qt.quit()
		}
	}
}
