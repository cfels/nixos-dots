import Quickshell
import QtQuick
import "moxi/components"
import "moxi/panel"

ShellRoot {
	id: scenario
	property int step: 0
	property int ticks: 0
	property double closedAt: 0
	property bool capturing: false
	Window {
		visible: true
		width: 920
		height: 600
		color: "black"
		PanelPager {
			id: pager
			width: settingsOpen ? 920 : 380
			height: settingsOpen ? 600 : 420
			panelExpanded: true
			Rectangle {
				parent: pager.desktopHost
				anchors.fill: parent
				color: "red"
			}
			settingsComponent: Item {
				property alias testColor: fill.color
				function show(page) {
				}
				Rectangle {
					id: fill
					anchors.fill: parent
					color: "blue"
				}
			}
		}
	}
	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}
	Timer {
		interval: 25
		running: true
		repeat: true
		onTriggered: {
			if (scenario.capturing)
				return
			try {
				if (++scenario.ticks > 200)
					throw new Error("Exit transition timed out at " + scenario.step)
				if (!Preferences.ready)
					return
				if (scenario.step === 0) {
					pager.showSettings("appearance")
					scenario.step++
				} else if (scenario.step === 1) {
					if (pager.transitioning || !pager.settingsItem)
						return
					pager.navigate()
					scenario.closedAt = Date.now()
					scenario.step++
				} else if (scenario.step === 2) {
					if (Date.now() - scenario.closedAt < 75)
						return
					scenario.check(pager.testSettings.width === 920 && pager.testSettings.height === 600, "Outgoing Settings reflowed during exit")
					scenario.check(pager.testExit.sourceItem === pager.settingsItem && !pager.testExit.live, "Exit did not retain a frozen GPU source")
					pager.settingsItem.testColor = "green"
					scenario.step++
				} else if (scenario.step === 3) {
					scenario.capturing = true
					pager.grabToImage(result => {
						result.saveToFile("/work/panel-settings-exit.png")
						scenario.capturing = false
						scenario.step++
					})
				} else {
					if (pager.transitioning)
						return
					scenario.check(!pager.settingsItem && !pager.testExit.sourceItem, "Closed Settings retained a page or GPU source")
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
