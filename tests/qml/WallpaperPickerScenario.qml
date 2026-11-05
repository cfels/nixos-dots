import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Window
import "panel"
import "components"

ShellRoot {
	id: scenario
	property int step: 0
	property int attempts: 0
	property int gifFrame: -1
	readonly property string walls: Quickshell.env("HOME") + "/walls/"

	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}

	function move(x, y): void {
		const point = view.testGrid.mapToItem(testWindow.contentItem, x, y)
		pointer.command = ["python3", "/work/move-pointer.py", Quickshell.env("X11_TEST_LIBRARY"), Quickshell.env("XTEST_TEST_LIBRARY"), String(Math.round(point.x)), String(Math.round(point.y))]
		pointer.running = true
		attempts = 0
	}

	function expected(name): bool {
		return subject.hoveredWallpaper === scenario.walls + name && subject.previewWallpaper === scenario.walls + name
	}

	WallpaperController {
		id: subject
		expanded: true
	}
	Theme {
		id: theme
	}
	Process {
		id: pointer
		stderr: StdioCollector {
			id: pointerError
		}
		onExited: (code, status) => {
			if (code !== 0) {
				console.error("PICKER_FAILED", pointerError.text)
				Qt.quit()
			}
		}
	}

	Window {
		id: testWindow
		x: 0
		y: 0
		width: 360
		height: 540
		visible: true
		Component.onCompleted: requestActivate()
		WallpaperView {
			id: view
			x: 40
			y: 30
			width: 260
			height: 440
			controller: subject
			theme: theme
		}
	}

	Timer {
		interval: 20
		repeat: true
		running: true
		onTriggered: {
			try {
				scenario.attempts++
				scenario.check(scenario.attempts < 150, "timed out at step " + scenario.step + ": hover=" + subject.hoveredWallpaper + ", preview=" + subject.previewWallpaper + ", scroll=" + view.testGrid.contentY)
				if (pointer.running)
					return
				const grid = view.testGrid
				if (scenario.step === 0) {
					if (subject.wallpapers.length !== 7)
						return
					scenario.move(grid.cellWidth / 2, grid.cellHeight / 2)
					scenario.step = 1
				} else if (scenario.step === 1) {
					if (!scenario.expected("00-red.png"))
						return
					scenario.move(grid.cellWidth * 1.5, grid.cellHeight / 2)
					scenario.step = 2
				} else if (scenario.step === 2) {
					if (!scenario.expected("01-green.png"))
						return
					scenario.move(grid.cellWidth - 7, grid.cellHeight / 2)
					scenario.step = 3
				} else if (scenario.step === 3) {
					if (!scenario.expected("00-red.png"))
						return
					scenario.move(grid.cellWidth - 2, grid.cellHeight / 2)
					scenario.step = 4
				} else if (scenario.step === 4) {
					if (subject.hoveredWallpaper !== "")
						return
					scenario.check(subject.previewWallpaper === scenario.walls + "00-red.png", "tile spacing must not select its neighbor")
					scenario.move(grid.cellWidth / 2, grid.cellHeight / 2)
					scenario.step = 5
				} else if (scenario.step === 5) {
					if (!scenario.expected("00-red.png"))
						return
					// Scroll the content without sending another pointer event.
					grid.contentY = grid.cellHeight
					scenario.attempts = 0
					scenario.step = 6
				} else if (scenario.step === 6) {
					if (!scenario.expected("02-blue.png") || Math.abs(grid.contentY - grid.cellHeight) > 1)
						return
					scenario.move(grid.width + 10, grid.cellHeight / 2)
					scenario.step = 7
				} else if (scenario.step === 7) {
					if (subject.hoveredWallpaper !== "")
						return
					grid.positionViewAtIndex(6, GridView.Contain)
					scenario.step = 8
					scenario.attempts = 0
				} else if (scenario.step === 8) {
					const tile = grid.itemAtIndex(6)
					if (!tile)
						return
					const pos = tile.mapToItem(grid, tile.width / 2, tile.height / 2)
					scenario.move(pos.x, pos.y)
					scenario.step = 9
				} else if (scenario.step === 9) {
					if (!scenario.expected("Velina.premiumwall.json") || !view.testPreview.ready || view.testPreview.source !== "file://" + subject.wallpaperSource(subject.previewWallpaper))
						return
					scenario.check(subject.wallpaperSourceAnimated(subject.previewWallpaper) && view.testPreview.animated, "premium preview must animate")
					scenario.check(view.testPreview.testAnimation.frameCount > 1, "premium GIF must contain multiple frames")
					scenario.gifFrame = view.testPreview.testAnimation.currentFrame
					scenario.attempts = 0
					scenario.step = 10
				} else if (scenario.step === 10) {
					if (scenario.attempts < 15)
						return
					scenario.check(view.testPreview.testAnimation.currentFrame !== scenario.gifFrame, "preview frames must advance while the panel is open")
					console.info("WALLPAPER_PICKER_OK")
					Qt.quit()
				}
			} catch (error) {
				console.error("PICKER_FAILED", error)
				Qt.quit()
			}
		}
	}
}
