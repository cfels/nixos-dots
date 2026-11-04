import Quickshell
import QtQuick
import "moxi/components"
import "moxi/settings"

ShellRoot {
	id: scenario
	property int step: 0
	property int attempts: 0
	Window {
		visible: true
		width: 320
		height: 180
		color: "black"
		SettingsCrossover {
			id: subject
			anchors.fill: parent
			Rectangle {
				id: page
				parent: subject.contentHost
				anchors.fill: parent
				color: "red"
			}
		}
	}
	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}
	Timer {
		interval: 20
		running: true
		repeat: true
		onTriggered: {
			try {
				if (++scenario.attempts > 250)
					throw new Error("Crossover timed out at " + scenario.step)
				if (!Preferences.ready)
					return
				if (scenario.step === 0) {
					subject.change(function () {
						page.color = "blue"
					}, 1)
					scenario.step++
				} else if (scenario.step === 1) {
					if (subject.capturing || subject.progress <= 0)
						return
					scenario.check(subject.busy && subject.snapshot !== null, "Outgoing page was lost during crossover")
					scenario.check(subject.contentHost.x > 0 && subject.contentHost.opacity > 0 && subject.contentHost.opacity < 1, "Incoming page did not crossfade from the right")
					scenario.step++
				} else if (scenario.step === 2) {
					if (subject.busy)
						return
					scenario.check(subject.snapshot === null && subject.progress === 1 && subject.contentHost.x === 0, "Crossover retained its capture or offset")
					subject.change(function () {
						page.color = "green"
					}, -1)
					subject.change(function () {
						page.color = "red"
					}, 1)
					Preferences.set("appearance.reducedMotion", true)
					scenario.step++
				} else if (scenario.step === 3) {
					if (!Preferences.reducedMotion || subject.busy)
						return
					scenario.check(page.color === Qt.color("red"), "Rapid navigation lost the newest request")
					subject.change(function () {
						page.color = "blue"
					}, -1)
					scenario.check(!subject.busy && subject.snapshot === null && page.color === Qt.color("blue"), "Reduced motion retained an animation or capture")
					console.info("SETTINGS_CROSSOVER_OK")
					Qt.quit()
				}
			} catch (error) {
				console.error("SETTINGS_CROSSOVER_FAILED", error)
				Qt.quit()
			}
		}
	}
}
