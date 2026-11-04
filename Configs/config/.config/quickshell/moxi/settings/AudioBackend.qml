import Quickshell
import Quickshell.Io
import QtQuick

Scope {
	id: audio
	property bool active: true
	property string error: ""
	property bool ready: false
	property string server: ""
	property var outputs: []
	property var queue: []
	property alias outputModel: outputRows
	property alias inputModel: inputRows
	property alias streamModel: streamRows
	readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/scripts/moxi-audio.py"
	ListModel {
		id: outputRows
	}
	ListModel {
		id: inputRows
	}
	ListModel {
		id: streamRows
	}

	function sync(model, items) {
		const keys = items.map(item => item.id + ":" + item.serial)
		for (let i = model.count - 1; i >= 0; --i) {
			const item = model.get(i).nodeData
			if (keys.indexOf(item.id + ":" + item.serial) === -1)
				model.remove(i)
		}
		for (const item of items) {
			let index = -1
			for (let i = 0; i < model.count; ++i)
				if (model.get(i).nodeData.id === item.id && model.get(i).nodeData.serial === item.serial) {
					index = i
					break
				}
			if (index < 0)
				model.append({
					nodeData: item
				})
			else
				model.setProperty(index, "nodeData", item)
		}
	}
	function ingest(line) {
		try {
			const data = JSON.parse(line)
			if (data.error) {
				error = data.error
				ready = false
				outputRows.clear()
				inputRows.clear()
				streamRows.clear()
				outputs = []
				return
			}
			sync(outputRows, data.outputs)
			sync(inputRows, data.inputs)
			sync(streamRows, data.streams)
			outputs = data.outputs
			server = data.server
			ready = true
			error = ""
		} catch (problem) {
			error = "Invalid audio response: " + problem
		}
	}
	function change(action, kind, node, value) {
		const request = {
			action: action,
			kind: kind,
			id: node.id,
			serial: node.serial,
			value: value
		}
		queue = queue.filter(item => item.action !== action || item.kind !== kind || item.id !== node.id).concat([request])
		next()
	}
	function next() {
		if (mutation.running || queue.length === 0 || !active)
			return
		mutation.command = ["python3", helper, "command", JSON.stringify(queue[0])]
		queue = queue.slice(1)
		mutation.running = true
	}
	function reconnect() {
		subscription.running = false
		reconnectTimer.restart()
	}
	onActiveChanged: if (!active)
		queue = []
	Timer {
		id: reconnectTimer
		interval: 100
		onTriggered: subscription.running = audio.active
	}
	Process {
		id: subscription
		command: ["python3", audio.helper, "watch"]
		running: audio.active
		stdout: SplitParser {
			onRead: line => audio.ingest(line)
		}
		stderr: StdioCollector {
			id: subscriptionError
		}
		onExited: (code, status) => {
			if (audio.active && code !== 0 && !audio.error)
				audio.error = subscriptionError.text.trim() || "Audio service disconnected. Reconnect to retry."
		}
	}
	Process {
		id: mutation
		stdout: SplitParser {
			onRead: line => {
				try {
					const data = JSON.parse(line)
					if (data.error)
						audio.error = data.error
				} catch (problem) {
					audio.error = String(problem)
				}
			}
		}
		stderr: StdioCollector {
			id: mutationError
		}
		onExited: (code, status) => {
			if (code !== 0 && mutationError.text.trim())
				audio.error = mutationError.text.trim()
			audio.next()
		}
	}
}
