import Quickshell
import Quickshell.Io
import QtQuick
import "panel"
import "settings"

ShellRoot {
	id: scenario
	property int step: 0
	property int attempts: 0
	property real beforeScroll: 0
	property bool captured: false
	readonly property string walls: Quickshell.env("HOME") + "/walls/"
	WallpaperController {
		id: library
		expanded: true
	}
	Window {
		id: testWindow
		visible: true
		width: 920
		height: 600
		color: "#11111b"
		SettingsContent {
			id: subject
			wallpaperLibrary: library
			anchors.fill: parent
			category: "wallpaper"
		}
	}
	Process {
		id: pointer
	}
	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}
	function move(view, x, y): void {
		const point = view.testGrid.mapToItem(testWindow.contentItem, x, y)
		pointer.command = ["python3", "/work/move-pointer.py", Quickshell.env("X11_TEST_LIBRARY"), Quickshell.env("XTEST_TEST_LIBRARY"), String(Math.round(point.x)), String(Math.round(point.y))]
		pointer.running = true
	}
	Timer {
		interval: 20
		running: true
		repeat: true
		onTriggered: {
			try {
				if (++scenario.attempts > 250)
					throw new Error("Settings gallery timed out at " + scenario.step + "; outer=" + subject.testScroll.contentY + "; before=" + scenario.beforeScroll)
				if (pointer.running || !subject.testWallpaper)
					return
				const gallery = subject.testWallpaper.testView
				const grid = gallery.testGrid
				const library = subject.testWallpaper.testLibrary
				const scroll = subject.testScroll
				if (scenario.step === 0) {
					if (library.wallpapers.length !== 7 || !gallery.testPreview.ready)
						return
					scenario.check(gallery.previewHeight >= 300 && Math.abs(gallery.width / gallery.previewHeight - 16 / 9) < 0.02, "Settings preview is not a large 16:9 surface")
					scenario.check(!grid.interactive && !grid.clip, "Settings gallery still owns a nested scrolling/clipping viewport")
					scenario.check(gallery.columns === 3 && Math.floor(grid.width / grid.cellWidth) === 3, "Settings gallery does not fit three thumbnails per row")
					scenario.check(grid.height >= Math.ceil(grid.count / gallery.columns) * grid.cellHeight, "Gallery height cuts off a thumbnail row")
					scroll.contentY = grid.y - 24
					scenario.move(gallery, grid.cellWidth / 2, grid.cellHeight / 2)
					scenario.step++
				} else if (scenario.step === 1) {
					if (library.hoveredWallpaper !== scenario.walls + "00-red.png")
						return
					const thumb = grid.itemAtIndex(0).testThumb
					if (thumb.scale < 1.05)
						return
					const top = thumb.mapToItem(grid, 0, 0)
					const bottom = thumb.mapToItem(grid, thumb.width, thumb.height)
					scenario.check(top.x >= 0 && top.y >= 0 && bottom.x <= grid.cellWidth && bottom.y <= grid.cellHeight, "Hovered thumbnail exceeds its padding")
					scroll.contentY += grid.cellHeight
					scenario.step++
				} else if (scenario.step === 2) {
					if (library.hoveredWallpaper !== scenario.walls + "03-yellow.png")
						return
					scenario.beforeScroll = scroll.contentY
					pointer.command = ["python3", "/work/move-pointer.py", Quickshell.env("X11_TEST_LIBRARY"), Quickshell.env("XTEST_TEST_LIBRARY"), "wheel", "5", "4"]
					pointer.running = true
					scenario.step++
				} else if (scenario.step === 3) {
					if (scroll.contentY <= scenario.beforeScroll + 10)
						return
					scenario.check(grid.contentY === 0, "Wheel input scrolled the inner gallery")
					scroll.contentY = 0
					scenario.move(gallery, -20, -20)
					scenario.step++
				} else if (scenario.step === 4) {
					if (library.hoveredWallpaper || !gallery.testPreview.ready)
						return
					if (!scenario.captured) {
						scenario.captured = true
						testWindow.contentItem.grabToImage(result => {
							result.saveToFile("/work/settings-gallery-top.png")
							scroll.contentY = grid.y - 24
							scenario.move(gallery, grid.cellWidth / 2, grid.cellHeight / 2)
							scenario.step++
						})
					}
				} else {
					if (library.hoveredWallpaper !== scenario.walls + "00-red.png")
						return
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
