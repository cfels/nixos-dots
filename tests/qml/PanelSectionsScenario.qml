import Quickshell
import QtQuick
import "moxi/components"
import "moxi/panel"

ShellRoot {
	id: scenario
	property int step: 0
	property int attempts: 0
	property int combination: 0
	property bool hosted: false
	property bool capturing: false
	readonly property var combinations: [
		{
			calendar: true,
			wallpapers: true,
			width: 920
		},
		{
			calendar: false,
			wallpapers: true,
			width: 650
		},
		{
			calendar: true,
			wallpapers: false,
			width: 650
		},
		{
			calendar: false,
			wallpapers: false,
			width: 380
		}
	]

	QtObject {
		id: bar
		property real pillWidth: 210
		property real pillHeight: 38
		property real pillTop: 4
		property color pillColor: "transparent"
		property color pillBorderColor: "transparent"
	}
	Window {
		visible: true
		width: 1000
		height: 700
		color: "#181820"
		Panel {
			id: subject
			width: 1000
			height: 700
			expanded: true
			surfaceHost: scenario.hosted ? island.panelHost : null
		}
		IslandWindow {
			id: island
			width: 1000
			barWindow: bar
			mode: scenario.hosted ? "panel" : ""
			panelWidth: subject.preferredWidth
			panelHeight: subject.preferredHeight
			panelSettings: subject.settingsVisible
		}
	}
	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}
	function applyCombination(): void {
		const configuration = combinations[combination]
		Preferences.set("bar.calendar", configuration.calendar)
		Preferences.set("bar.wallpapers", configuration.wallpapers)
	}
	function checkColumns(): void {
		const configuration = combinations[combination]
		check(subject.testCalendar.visible === configuration.calendar, "Calendar visibility mismatch")
		check(subject.testWallpaperView.visible === configuration.wallpapers, "Wallpaper visibility mismatch")
		check(subject.testPlayerView.width === 340, "Player width changed")
		const items = [subject.testCalendar, subject.testPlayerView, subject.testWallpaperView].filter(item => item.visible)
		const first = items[0].mapToItem(subject.testSurface, 0, 0)
		check(Math.abs(first.x - 20) < 0.5, "Content is not aligned with the left padding: " + first.x)
		for (let i = 1; i < items.length; ++i) {
			const previous = items[i - 1].mapToItem(subject.testSurface, items[i - 1].width, 0)
			const current = items[i].mapToItem(subject.testSurface, 0, 0)
			check(Math.abs(current.x - previous.x - 41) < 0.5, "Section gap or separator is incorrect")
		}
		const last = items[items.length - 1].mapToItem(subject.testSurface, items[items.length - 1].width, 0)
		check(Math.abs(last.x - (configuration.width - 20)) < 0.5, "Content leaves unused space on the right: " + last.x)
	}
	Timer {
		interval: 50
		running: true
		repeat: true
		onTriggered: {
			try {
				scenario.check(++scenario.attempts < 300, "Section layout timed out at step " + scenario.step)
				if (!Preferences.ready || Preferences.saving || scenario.capturing)
					return
				if (scenario.step === 0) {
					scenario.applyCombination()
					scenario.step++
				} else if (scenario.step === 1) {
					const configuration = scenario.combinations[scenario.combination]
					// Preference reads and the next layout polish can land on separate frames.
					if (subject.preferredWidth !== configuration.width)
						return
					if (Math.abs(subject.testSurface.width - configuration.width) > 0.5 || (scenario.hosted && (island.progress < 0.999 || Math.abs(island.testSurface.width - configuration.width) > 0.5)))
						return
					scenario.checkColumns()
					scenario.capturing = true
					const surface = scenario.hosted ? island.testSurface : subject.testSurface
					surface.grabToImage(result => {
						result.saveToFile("/work/panel-sections-" + (scenario.hosted ? "island-" : "standalone-") + scenario.combination + ".png")
						scenario.capturing = false
						scenario.step++
					})
				} else if (scenario.step === 2) {
					if (++scenario.combination < scenario.combinations.length) {
						scenario.step = 0
					} else if (!scenario.hosted) {
						scenario.hosted = true
						scenario.combination = 0
						scenario.step = 0
					} else {
						scenario.combination = scenario.combinations.length - 1
						subject.showSettings("bar")
						scenario.step++
					}
				} else if (scenario.step === 3) {
					if (subject.testPager.transitioning || Math.abs(island.testSurface.width - 920) > 0.5)
						return
					scenario.check(subject.settingsVisible && subject.preferredWidth === 920, "Settings inherited the narrow player width")
					subject.testPager.navigate()
					scenario.step++
				} else if (scenario.step === 4) {
					if (subject.testPager.transitioning || Math.abs(island.testSurface.width - 380) > 0.5)
						return
					scenario.checkColumns()
					Preferences.set("appearance.reducedMotion", true)
					scenario.step++
				} else if (scenario.step === 5) {
					if (!Preferences.reducedMotion)
						return
					scenario.combination = 0
					scenario.applyCombination()
					scenario.step++
				} else {
					scenario.check(island.testSurface.width === 920 && subject.preferredWidth === 920, "Reduced-motion layout did not resize immediately")
					scenario.checkColumns()
					console.log("PANEL_SCENARIO_OK")
					Qt.quit()
				}
			} catch (error) {
				console.error("PANEL_SCENARIO_FAILED", scenario.step, scenario.combination, scenario.hosted, error, error.stack)
				Qt.quit()
			}
		}
	}
}
