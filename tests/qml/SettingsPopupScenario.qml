import Quickshell
import QtQuick
import "moxi/settings"
import "moxi/components"

ShellRoot {
	id: scenario
	property int step: 0
	property int attempts: 0
	property bool capturing: false
	Window {
		id: testWindow
		visible: true
		width: 320
		height: 300
		Item {
			id: scene
			anchors.fill: parent
			Repeater {
				model: 32
				Rectangle {
					required property int index
					x: index * 10
					width: 10
					height: scene.height
					color: index % 2 ? "blue" : "red"
				}
			}
			SettingsChoice {
				id: choice
				x: 60
				y: 50
				width: 200
				model: ["cover", "contain"]
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
					throw new Error("Popup timed out at " + scenario.step)
				if (!Preferences.ready || scenario.capturing)
					return
				if (scenario.step === 0) {
					choice.popup.open()
					scenario.step++
				} else if (scenario.step === 1) {
					if (choice.popup.opacity <= 0)
						return
					scenario.check(choice.popup.opacity < 1 && choice.popup.scale < 1, "Popup skipped its opening animation")
					scenario.step++
				} else if (scenario.step === 2) {
					if (choice.popup.opacity < 1 || choice.popup.scale < 1)
						return
					scenario.check(choice.popup.background.sourceItem === scene, "Backdrop source includes the popup overlay")
					scenario.check(choice.popup.background.blurEnabled, "Popup backdrop blur is disabled")
					const row = choice.testList.itemAtIndex(0)
					scenario.check(row && row.width === choice.testList.width && row.width < choice.popup.width, "Option row exceeds its padded viewport")
					scenario.capturing = true
					testWindow.contentItem.grabToImage(result => {
						result.saveToFile("/work/settings-popup-open.png")
						scenario.capturing = false
						choice.popup.close()
						scenario.step++
					})
				} else if (scenario.step === 3) {
					if (choice.popup.opacity === 1)
						return
					scenario.check(choice.popup.visible && choice.popup.opacity > 0 && choice.popup.opacity < 1, "Popup skipped its closing animation: " + choice.popup.visible + ", " + choice.popup.opacity)
					scenario.check(choice.testList.count === 2, "Closing animation discarded the rows early")
					scenario.step++
				} else if (scenario.step === 4) {
					if (choice.popup.visible)
						return
					scenario.check(!choice.popup.background.blurEnabled, "Closed popup retained active blur")
					Preferences.set("appearance.reducedMotion", true)
					scenario.step++
				} else if (scenario.step === 5) {
					if (!Preferences.reducedMotion)
						return
					choice.popup.open()
					scenario.step++
				} else if (scenario.step === 6) {
					scenario.check(choice.popup.opacity === 1 && choice.popup.scale === 1, "Reduced motion did not finish the popup immediately")
					choice.popup.close()
					scenario.step++
				} else {
					scenario.check(!choice.popup.visible, "Reduced motion left the popup open")
					console.info("SETTINGS_POPUP_OK")
					Qt.quit()
				}
			} catch (error) {
				console.error("SETTINGS_POPUP_FAILED", error)
				Qt.quit()
			}
		}
	}
}
