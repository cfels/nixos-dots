import Quickshell
import QtQuick
import "moxi/components"

ShellRoot {
	id: scenario
	property int step: 0
	property double since: 0
	property int ticks: 0
	Timer {
		interval: 50
		running: true
		repeat: true
		onTriggered: {
			try {
				if (++scenario.ticks > 160)
					throw new Error("Message expiry timed out")
				if (!Preferences.ready)
					return
				if (scenario.step === 0) {
					Preferences.saveError = "Keep this error visible"
					Preferences.message = "Defaults restored."
					scenario.since = Date.now()
					scenario.step++
				} else if (scenario.step === 1) {
					if (Date.now() - scenario.since < 1500)
						return
					if (!Preferences.message)
						throw new Error("Success message disappeared too early")
					Preferences.message = "Changes applied."
					scenario.since = Date.now()
					scenario.step++
				} else {
					const elapsed = Date.now() - scenario.since
					if (elapsed < 3400) {
						if (Preferences.message !== "Changes applied.")
							throw new Error("New message inherited the previous timeout")
						return
					}
					if (Preferences.message)
						return
					if (Preferences.saveError !== "Keep this error visible")
						throw new Error("Success expiry cleared an error")
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
