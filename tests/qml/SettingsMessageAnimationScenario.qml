import Quickshell
import QtQuick
import "moxi/components"
import "moxi/panel"
import "moxi/settings"

ShellRoot {
	id: scenario
	property int step: -1
	property int ticks: 0
	property real fullHeight: 0
	property real restingPageY: 0
	property real expandedPageY: 0
	WallpaperController {
		id: library
	}
	Window {
		visible: true
		width: 920
		height: 600
		SettingsContent {
			id: settings
			anchors.fill: parent
			wallpaperLibrary: library
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
				if (++scenario.ticks > 200)
					throw new Error("Message animation timed out at " + scenario.step)
				if (!Preferences.ready)
					return
				if (scenario.step < 0) {
					scenario.step = 0
					return
				}
				const status = settings.testStatus
				if (scenario.step === 0) {
					scenario.restingPageY = settings.testCrossover.y
					Preferences.message = "Defaults restored."
					scenario.step++
				} else if (scenario.step === 1) {
					if (status.reveal < 1)
						return
					scenario.fullHeight = status.height
					scenario.expandedPageY = settings.testCrossover.y
					scenario.check(scenario.expandedPageY > scenario.restingPageY, "Message did not push the settings down")
					Preferences.message = ""
					scenario.step++
				} else if (scenario.step === 2) {
					if (status.reveal > 0.6)
						return
					scenario.check(status.reveal > 0 && status.opacity > 0, "Message disappeared without a fade")
					scenario.check(status.shownText === "Defaults restored.", "Text vanished before the fade finished")
					scenario.check(status.height > 0 && status.height < scenario.fullHeight, "Message space did not collapse with its fade")
					scenario.check(settings.testCrossover.y > scenario.restingPageY && settings.testCrossover.y < scenario.expandedPageY, "Settings below the fading message snapped instead of moving")
					scenario.check(!status.clip, "Message slide is clipped")
					const label = status.children.find(item => item.text !== undefined)
					scenario.check(label.layer.enabled && label.opacity > 0 && label.opacity < 1 && label.transform[0].y < 0, "Message did not use a blurred slide")
					scenario.step++
				} else if (scenario.step === 3) {
					if (status.reveal > 0)
						return
					scenario.check(!status.visible && !status.shownText && status.implicitHeight === 0, "Message retained space after fading")
					scenario.check(Math.abs(settings.testCrossover.y - scenario.restingPageY) <= 1, "Hidden message left a gap in the settings")
					Preferences.message = "Changes applied."
					scenario.step++
				} else if (scenario.step === 4) {
					if (status.reveal < 1)
						return
					Preferences.message = ""
					scenario.step++
				} else if (scenario.step === 5) {
					if (status.reveal === 1)
						return
					scenario.check(status.reveal > 0, "Fade finished before the replacement")
					Preferences.message = "Defaults restored."
					scenario.step++
				} else if (scenario.step === 6) {
					if (status.reveal < 1)
						return
					scenario.check(status.shownText === "Defaults restored.", "New success was lost during a fade")
					Preferences.saveError = "Keep this error visible"
					Preferences.message = ""
					scenario.step++
				} else if (scenario.step === 7) {
					scenario.check(status.reveal === 1 && status.shownError, "Error was faded with the success message")
					Preferences.values = Object.assign({}, Preferences.values, {
						"appearance.reducedMotion": true
					})
					Preferences.saveError = ""
					scenario.step++
				} else {
					scenario.check(status.reveal === 0 && !status.visible, "Reduced motion retained a fade")
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
