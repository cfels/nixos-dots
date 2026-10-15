import Quickshell
import Quickshell.Io
import QtQuick

Item {
	id: root

	signal captured()

	property bool active: false
	property string outputPath: ""
	property string freezeSource: ""
	property int freezeVersion: 0
	readonly property string freezePath: Quickshell.env("XDG_RUNTIME_DIR") + "/moxi-freeze.png"

	readonly property string captureScript: Quickshell.env("HOME") + "/.config/hypr/scripts/screenshot-capture.sh"

	function capture(geometry: string, path: string): void {
		root.active = false
		captureProcess.nextGeometry = geometry
		captureProcess.nextPath = path
		captureProcess.running = true
	}

	IpcHandler {
		target: "screenshot"

		function region(path: string): void {
			root.outputPath = path
			root.active = false
			freeze.running = true
		}

		function full(path: string): void {
			root.capture("full", path)
		}

		function cancel(): void {
			root.active = false
		}
	}

	Process {
		id: freeze

		command: ["bash", "-c", "grim \"$1\" 2>/dev/null", "freeze", root.freezePath]

		onExited: (code, status) => {
			root.freezeVersion = root.freezeVersion + 1
			root.freezeSource = code === 0 ? "file://" + root.freezePath + "?v=" + root.freezeVersion : ""
			root.active = true
		}
	}

	Process {
		id: captureProcess

		property string nextGeometry: "full"
		property string nextPath: ""

		command: [root.captureScript, captureProcess.nextGeometry, captureProcess.nextPath]

		onExited: (code, status) => {
			if (code === 0) root.captured()
		}
	}

	Process {
		id: cropProcess

		property int nextX: 0
		property int nextY: 0
		property int nextW: 0
		property int nextH: 0

		command: [
			root.captureScript,
			"frozen",
			String(cropProcess.nextX),
			String(cropProcess.nextY),
			String(cropProcess.nextW),
			String(cropProcess.nextH),
			root.outputPath
		]

		onExited: (code, status) => {
			if (code === 0) root.captured()
		}
	}

	Connections {
		target: overlay.item

		function onSelected(x, y, width, height) {
			cropProcess.nextX = x
			cropProcess.nextY = y
			cropProcess.nextW = width
			cropProcess.nextH = height
			root.active = false
			cropProcess.running = true
		}

		function onCancelled() {
			root.active = false
		}
	}

	LazyLoader {
		id: overlay

		active: root.active

		Geom {
			freezeSource: root.freezeSource
		}
	}
}
