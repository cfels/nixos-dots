import Quickshell
import QtQuick
import "moxi/settings"

ShellRoot {
	id: scenario
	property int outputChanges: 0
	property int inputChanges: 0
	property int outputLists: 0
	AudioBackend {
		id: audio
		active: false
		onOutputsChanged: scenario.outputLists++
	}
	Connections {
		target: audio.outputModel
		function onDataChanged() {
			scenario.outputChanges++
		}
	}
	Connections {
		target: audio.inputModel
		function onDataChanged() {
			scenario.inputChanges++
		}
	}
	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}
	Timer {
		interval: 30
		running: true
		onTriggered: {
			try {
				const state = {
					outputs: [
						{
							id: 3,
							serial: "103",
							label: "Headphones",
							volume: 40
						}
					],
					inputs: [
						{
							id: 4,
							serial: "104",
							label: "Microphone",
							volume: 50
						}
					],
					streams: [],
					server: "Test audio"
				}
				audio.ingest(JSON.stringify(state))
				const initialLists = scenario.outputLists
				const initialOutputs = scenario.outputChanges
				const initialInputs = scenario.inputChanges
				for (let i = 0; i < 20; ++i)
					audio.ingest(JSON.stringify(state))
				scenario.check(scenario.outputChanges === initialOutputs && scenario.inputChanges === initialInputs && scenario.outputLists === initialLists, "Unchanged audio state refreshed the controls")
				state.inputs[0].volume = 55
				audio.ingest(JSON.stringify(state))
				scenario.check(scenario.inputChanges > initialInputs && audio.inputModel.get(0).nodeData.volume === 55, "External microphone change was lost")
				scenario.check(scenario.outputChanges === initialOutputs && scenario.outputLists === initialLists, "Microphone event rebuilt the output controls")
				state.outputs[0].volume = 70
				audio.ingest(JSON.stringify(state))
				scenario.check(scenario.outputChanges > initialOutputs && audio.outputModel.get(0).nodeData.volume === 70, "External output volume was lost")
				state.outputs = []
				audio.ingest(JSON.stringify(state))
				scenario.check(audio.outputModel.count === 0 && audio.outputs.length === 0, "Disconnected output was retained")
				console.info("PANEL_SCENARIO_OK")
				Qt.quit()
			} catch (error) {
				console.error("PANEL_SCENARIO_FAILED", error)
				Qt.quit()
			}
		}
	}
}
