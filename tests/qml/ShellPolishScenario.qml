import Quickshell
import QtQuick
import "moxi/components"
import "moxi/panel"

ShellRoot {
	id: scenario
	property int step: 0
	property int ticks: 0
	property bool capturing: false
	QtObject {
		id: bar
		property real pillWidth: 210
		property real pillHeight: 38
		property real pillTop: 4
		property color pillColor: "#181820"
		property color pillBorderColor: "#555566"
	}
	Theme {
		id: theme
	}
	PanelFonts {
		id: fonts
	}
	PlayerController {
		id: media
	}
	LyricsController {
		id: lyrics
		media: media
	}
	Window {
		visible: true
		width: 1000
		height: 600
		color: "black"
		Rectangle {
			id: cornerFrame
			x: 350
			width: 128
			height: 128
			color: "white"
			Repeater {
				model: [0, 90, 180, 270]
				ScreenCorner {
					required property int modelData
					width: 32
					height: 32
					x: modelData === 90 || modelData === 180 ? 96 : 0
					y: modelData >= 180 ? 96 : 0
					rotation: modelData
				}
			}
		}
		LyricsView {
			id: view
			width: 310
			height: 200
			media: media
			controller: lyrics
			theme: theme
			fonts: fonts
		}
		Rectangle {
			parent: view.testList.contentItem
			y: view.testList.contentY
			width: view.testList.width
			height: view.testList.height
			color: "white"
		}
		IslandWindow {
			id: island
			width: 1000
			barWindow: bar
		}
	}
	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}
	function capture(item, name): void {
		capturing = true
		item.grabToImage(function (result) {
			if (!result.saveToFile("/work/panel-" + name + ".png"))
				console.error("PANEL_SCENARIO_FAILED", "Capture failed", name)
			capturing = false
			step++
		})
	}
	Timer {
		interval: 50
		running: true
		repeat: true
		onTriggered: {
			if (scenario.capturing)
				return
			if (++scenario.ticks > 180) {
				console.error("PANEL_SCENARIO_FAILED", "Polish check timed out", scenario.step)
				Qt.quit()
				return
			}
			try {
				if (scenario.step === 0) {
					if (!Preferences.ready)
						return
					lyrics.lyricsMix = 1
					scenario.step++
				} else if (scenario.step === 1) {
					if (lyrics.lyricsFade < 0.999)
						return
					scenario.capture(view, "lyrics-fade")
				} else if (scenario.step === 2) {
					scenario.capture(cornerFrame, "screen-corners")
				} else if (scenario.step === 3) {
					island.mode = "panel"
					scenario.step++
				} else if (scenario.step === 4) {
					if (island.progress < 0.999 || Math.abs(island.testSurface.width - 920) > 0.1)
						return
					island.mode = ""
					scenario.step++
				} else if (scenario.step === 5) {
					scenario.check(island.progress > 0 && island.progress < 1, "Close did not animate")
					scenario.check(island.testSurface.width > 210 && island.testSurface.width < 920, "Close jumped to its endpoint")
					island.mode = "panel"
					scenario.step++
				} else if (scenario.step === 6) {
					if (island.progress < 0.999 || Math.abs(island.testSurface.width - 920) > 0.1)
						return
					island.mode = ""
					scenario.step++
				} else if (scenario.step === 7) {
					if (island.progress > 0)
						return
					scenario.check(Math.abs(island.testSurface.width - 210) < 0.1, "Close missed the bar: " + island.testSurface.width + ", progress " + island.progress)
					Preferences.values = Object.assign({}, Preferences.values, {
						"appearance.reducedMotion": true
					})
					island.mode = "panel"
					scenario.step++
				} else if (scenario.step === 8) {
					scenario.check(island.progress === 1, "Reduced motion still animates opening")
					island.mode = ""
					scenario.step++
				} else {
					scenario.check(island.progress === 0 && !island.visible, "Reduced motion still animates closing")
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
