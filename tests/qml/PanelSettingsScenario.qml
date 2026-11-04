import Quickshell
import QtQuick
import "moxi/panel"
import "moxi/components"

ShellRoot {
	id: scenario
	property int step: 0
	property int waits: 0
	property int cycles: 0
	property bool captured: false
	property bool grabbing: false
	Window {
		visible: true
		width: 1000
		height: 740
		Panel {
			id: subject
			width: 1000
			height: 740
		}
	}
	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}
	Timer {
		interval: 50
		running: true
		repeat: true
		onTriggered: {
			try {
				if (++scenario.waits > 300)
					throw new Error("Panel Settings timed out at step " + scenario.step)
				const pager = subject.testPager
				if (scenario.step === 0) {
					subject.inputReady = false
					subject.expanded = true
					scenario.step++
				} else if (scenario.step === 1) {
					if (!subject.contentVisible || pager.transitioning || !Preferences.ready)
						return
					scenario.check(!subject.testPlayerView.enabled, "Player accepts input while the island is opening")
					subject.inputReady = true
					scenario.check(subject.testPlayerView.enabled, "Player remains disabled after opening")
					scenario.check(!pager.settingsItem, "Settings loaded before opening")
					pager.finishSwipe(40, 0)
					pager.finishSwipe(100, 120)
					scenario.check(!subject.settingsVisible, "Short or vertical drag switched pages")
					pager.finishSwipe(-150, 0)
					scenario.check(subject.settingsVisible, "Left swipe did not open Settings")
					scenario.step++
				} else if (scenario.step === 2) {
					if (pager.desktopHost.x === 0)
						return
					scenario.check(pager.transitioning, "Page transition did not animate")
					pager.navigate()
					scenario.check(subject.settingsVisible, "Repeated navigation interrupted animation")
					scenario.check(pager.desktopHost.x > 0 && pager.desktopHost.x < pager.width, "Transition did not move left to right: " + pager.desktopHost.x)
					scenario.step++
				} else if (scenario.step === 3) {
					if (pager.transitioning)
						return
					scenario.check(pager.settingsItem && pager.settingsItem.embedded && pager.settingsItem.active, "Embedded Settings missing or inactive")
					scenario.check(pager.settingsItem.wallpaperLibrary === subject.testWallpaper, "Settings duplicated the panel wallpaper library")
					scenario.check(subject.preferredHeight === 600, "Settings panel did not expand")
					scenario.check(!subject.testWallpaper.expanded && !subject.testMedia.expanded, "Hidden panel retained preview playback or fast media updates")
					if (!scenario.captured) {
						if (!scenario.grabbing) {
							scenario.grabbing = true
							subject.testSurface.grabToImage(result => {
								result.saveToFile("/work/panel-settings.png")
								scenario.captured = true
							})
						}
						return
					}

					scenario.check(!pager.settingsItem.categories.some(item => item.key === "mouse"), "Removed mouse tab remains")
					pager.finishSwipe(-150, 0)
					scenario.step = 20
				} else if (scenario.step === 20) {
					if (pager.settingsItem.transitioning)
						return
					scenario.check(subject.settingsVisible && pager.settingsItem.category === "wallpaper", "Swipe did not navigate to the next category")
					scenario.check(pager.settingsItem.testCrossover.direction === -1, "Forward category change did not enter from the left")
					scenario.check(subject.testWallpaper.expanded && !subject.testWallpaperView.active, "Hidden normal picker animates while Settings uses its library")
					pager.finishSwipe(150, 0)
					scenario.step = 21
				} else if (scenario.step === 21) {
					if (pager.settingsItem.transitioning)
						return
					scenario.check(subject.settingsVisible && pager.settingsItem.category === "appearance", "Swipe did not navigate to the previous category")
					scenario.check(pager.settingsItem.testCrossover.direction === -1, "Backward category change did not enter from the left")
					pager.settingsItem.selectCategory("notifications")
					scenario.step = 22
				} else if (scenario.step === 22) {
					if (pager.settingsItem.transitioning)
						return
					pager.settingsItem.query = "duration"
					scenario.check(pager.settingsItem.rows.some(item => item.key === "notifications.duration"), "Embedded search missing settings")
					pager.settingsItem.closeRequested()
					scenario.check(pager.direction === 1, "Returning to the panel did not enter from the left")
					scenario.step = 4
				} else if (scenario.step === 4) {
					if (pager.transitioning)
						return
					scenario.check(!subject.settingsVisible && !pager.settingsItem, "Settings retained background work after closing")
					pager.finishSwipe(150, 0)
					scenario.check(subject.settingsVisible && pager.direction === -1, "Right swipe did not open from the left")
					scenario.step++
				} else if (scenario.step === 5) {
					if (pager.transitioning)
						return
					pager.finishSwipe(150, 0)
					scenario.check(!subject.settingsVisible, "Right swipe did not return from the first category")
					scenario.step++
				} else if (scenario.step === 6) {
					if (pager.transitioning)
						return
					if (++scenario.cycles < 3) {
						scenario.step = 4
						return
					}
					Preferences.set("appearance.reducedMotion", true)
					scenario.step++
				} else if (scenario.step === 7) {
					if (Preferences.busy || !Preferences.value("appearance.reducedMotion", false))
						return
					pager.navigate()
					scenario.step++
				} else if (scenario.step === 8) {
					scenario.check(!pager.transitioning && subject.settingsVisible && pager.settingsItem, "Reduced motion failed to finish")
					subject.expanded = false
					scenario.step++
				} else {
					if (subject.surfaceVisible)
						return
					scenario.check(!subject.settingsVisible && !pager.settingsItem, "Collapsed panel retained Settings")
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
