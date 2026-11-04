import Quickshell
import Quickshell.Io
import QtQuick
import "moxi/panel"
import "moxi/settings"
import "moxi/components"

ShellRoot {
	id: scenario
	property int step: 0
	property int waits: 0
	property int categoryIndex: 0
	property bool captured: false
	property bool motionChecked: false
	property bool revealOpened: false
	BarReveal {
		id: reducedReveal
	}
	WallpaperController { id: library }
	Window {
        visible: true
        width: 920
        height: 600
        SettingsContent { wallpaperLibrary: library; id: settings; anchors.fill: parent; embedded: true }
    }
	AudioBackend {
		id: audio
		active: false
	}
	FileView {
		id: external
		path: Preferences.path
		atomicWrites: true
	}
	Timer {
		interval: 100
		running: true
		repeat: true
		onTriggered: {
			try {
				if (++scenario.waits > 240)
					throw new Error("Timed out at settings step " + scenario.step)
				if (scenario.step === 0) {
					if (!Preferences.ready)
						return
					if (Preferences.error)
						throw new Error(Preferences.error)
					if (settings.rows.length < 10)
						throw new Error("Appearance controls missing")
					audio.ingest(JSON.stringify({
						outputs: [
							{
								id: 1,
								serial: "1",
								volume: 42
							}
						],
						inputs: [],
						streams: [
							{
								id: 2,
								serial: "2",
								volume: 80
							}
						],
						server: "test"
					}))
					audio.ingest(JSON.stringify({
						outputs: [
							{
								id: 1,
								serial: "1",
								volume: 73,
								default: true
							}
						],
						inputs: [],
						streams: [],
						server: "test"
					}))
					if (audio.outputModel.count !== 1 || audio.outputModel.get(0).nodeData.volume !== 73 || audio.streamModel.count !== 0)
						throw new Error("Audio state did not synchronize")
					for (let i = 0; i < 12; ++i)
						Preferences.set("audio.scrollStep", i + 1)
					Preferences.set("bar.media", false)
					scenario.step++
				} else if (scenario.step === 1) {
					if (Preferences.saving || Preferences.value("audio.scrollStep", 0) !== 12 || Preferences.value("bar.media", true))
						return
					external.setText("{broken")
					scenario.step++
				} else if (scenario.step === 2) {
					if (!Preferences.error)
						return
					if (Preferences.value("audio.scrollStep", 0) !== 12)
						throw new Error("Invalid JSON discarded last valid preferences")
					external.setText(JSON.stringify({
						version: 1,
						values: {
							"bar.media": true,
							"appearance.reducedMotion": true
						},
						wallpapers: {}
					}))
					scenario.step++
				} else if (scenario.step === 3) {
					if (Preferences.error || !Preferences.reducedMotion || !Preferences.value("bar.media", false))
						return
					if (!scenario.revealOpened) {
						reducedReveal.revealed = true
						scenario.revealOpened = true
						return
					}
					if (!scenario.motionChecked) {
						if (reducedReveal.progress < 0.999)
							throw new Error("Reduced-motion reveal did not complete")
						reducedReveal.revealed = false
						scenario.motionChecked = true
						return
					}
					if (reducedReveal.progress > 0.001)
						throw new Error("Reduced-motion close did not complete")
					Preferences.reset("appearance.reducedMotion")
					scenario.step++
				} else if (scenario.step === 4) {
					if (Preferences.saving || Preferences.reducedMotion)
						return
					settings.query = "volume"
					if (!settings.rows.some(item => item.key === "audio.scrollStep"))
						throw new Error("Settings search missed volume")
					settings.selectedManifest = {
						manifestPath: "/work/Velina.premiumwall.json",
						defaults: {
							openingEnabled: true
						}
					}
					settings.query = "opening"
					if (!settings.rows.some(item => item.key === "premium.openingEnabled"))
						throw new Error("Premium preferences missing from search")
					settings.selectedManifest = ({})
					settings.query = ""
					scenario.step++
				} else if (scenario.step === 5) {
					settings.category = settings.categories[scenario.categoryIndex].key
					scenario.step++
				} else if (scenario.step === 6) {
					if (settings.category === "audio" && scenario.waits % 5 !== 0)
						return
					if (!scenario.captured) {
						scenario.captured = true
						settings.grabToImage(result => {
							result.saveToFile("/work/settings-" + settings.category + ".png")
							scenario.step = 7
						})
					}
				} else if (scenario.step === 7) {
					settings.visible = false
					scenario.step++
				} else if (scenario.step === 8) {
					settings.visible = true
					scenario.captured = false
					if (++scenario.categoryIndex < settings.categories.length)
						scenario.step = 5
					else
						scenario.step++
				} else {
					console.info("SETTINGS_SCENARIO_OK")
					Qt.quit()
				}
			} catch (problem) {
				console.error("SETTINGS_SCENARIO_FAILED", problem)
				Qt.quit()
			}
		}
	}
	Timer {
		interval: 26000
		running: true
		onTriggered: {
			console.error("SETTINGS_SCENARIO_TIMEOUT")
			Qt.quit()
		}
	}
}
