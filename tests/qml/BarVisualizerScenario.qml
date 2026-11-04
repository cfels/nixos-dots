import Quickshell
import QtQuick
import QtQuick.Layouts
import "bar"
import "components"

ShellRoot {
	id: scenario
	property int step: 0
	property int attempts: 0
	QtObject {
		id: bar
		property bool playing: true
		property var sink: ({})
		property bool sinkMuted: false
		property color accent: "white"
	}
	Window {
		visible: true
		width: 200
		height: 60
		RowLayout {
			id: row
			spacing: 8
			Rectangle {
				implicitWidth: 20
				implicitHeight: 20
			}
			AudioVisualizer {
				id: subject
				// BAR_VISUALIZER
			}
			Rectangle {
				implicitWidth: 20
				implicitHeight: 20
			}
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
				scenario.check(++scenario.attempts < 100, "Timed out at visualizer step " + scenario.step)
				if (!Preferences.ready || Preferences.saving)
					return
				if (scenario.step === 0) {
					if (subject.levels[0] === 0)
						return
					scenario.check(subject.visible && subject.active, "Enabled visualizer missing")
					Preferences.set("bar.visualizer", false)
					scenario.step++
				} else if (scenario.step === 1) {
					if (Preferences.value("bar.visualizer", true) || subject.testExits !== 1)
						return
					scenario.check(!subject.visible && !subject.active, "Disabled visualizer still draws idle dots")
					scenario.check(row.implicitWidth === 48, "Disabled visualizer retains layout space: " + row.implicitWidth)
					Preferences.set("bar.visualizer", true)
					scenario.step++
				} else if (scenario.step === 2) {
					if (!Preferences.value("bar.visualizer", false) || subject.levels[0] === 0)
						return
					scenario.check(subject.visible && subject.active, "Re-enabled visualizer did not restart")
					bar.playing = false
					scenario.step++
				} else {
					if (subject.testExits !== 2)
						return
					scenario.check(subject.visible && !subject.active, "Pausing hides an enabled visualizer")
					scenario.check(row.implicitWidth === 84, "Enabled idle visualizer lost its layout space")
					console.log("BAR_VISUALIZER_OK")
					Qt.quit()
				}
			} catch (error) {
				console.error("BAR_VISUALIZER_FAILED", error)
				Qt.quit()
			}
		}
	}
}
