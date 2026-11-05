import Quickshell
import QtQuick
import "moxi/components"
import "moxi/panel"
import "moxi/settings"

ShellRoot {
	id: scenario
	property int step: 0
	property int ticks: 0
	property real fullHeight: 0
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
				const status = settings.testStatus
				if (scenario.step === 0) {
					Preferences.message = "Defaults restored."
					scenario.step++
				} else if (scenario.step === 1) {
					if (status.reveal < 1)
						return
					scenario.fullHeight = status.height
					Preferences.message = ""
					scenario.step++
				} else if (scenario.step === 2) {
					if (status.reveal === 1)
						return
					scenario.check(status.reveal > 0 && status.opacity > 0, "Message disappeared without a fade")
					scenario.check(status.shownText === "Defaults restored.", "Text vanished before the fade finished")
					scenario.check(Math.abs(status.height - scenario.fullHeight) < 1 && status.space === 1, "Message was clipped by an early collapse")
					scenario.check(!status.clip, "Message slide is clipped")
					const label = status.children.find(item => item.text !== undefined)
					scenario.check(label.layer.enabled && label.opacity > 0 && label.opacity < 1 && label.transform[0].y < 0, "Message did not use a blurred slide")
					scenario.step++
				} else if (scenario.step === 3) {
					if (status.reveal > 0 || status.space > 0)
						return
					scenario.check(!status.visible && !status.shownText && status.implicitHeight === 0, "Message retained space after fading")
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
