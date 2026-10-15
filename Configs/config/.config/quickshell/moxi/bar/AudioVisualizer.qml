pragma ComponentBehavior: Bound

import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Item {
	id: visualizer

	required property bool active
	required property color color
	property list<real> levels: [0, 0, 0, 0, 0]

	implicitWidth: 28
	implicitHeight: 22

	onActiveChanged: {
		if (!visualizer.active) visualizer.levels = [0, 0, 0, 0, 0]
	}

	function updateLevels(data: string): void {
		if (!visualizer.active) return

		var values = data.trim().split(";")
		if (values[values.length - 1] === "") values.pop()
		if (values.length !== 15) return

		var spectrum = []
		for (var i = 0; i < values.length; ++i) {
			if (values[i].trim() === "") return
			var value = Number(values[i])
			if (!isFinite(value)) return
			spectrum.push(Math.max(0, Math.min(1, value / 1000)))
		}

		var next = []
		for (var band = 0; band < 5; ++band) {
			var energy = 0
			for (var bin = 0; bin < 3; ++bin) {
				var amplitude = spectrum[band * 3 + bin]
				energy += amplitude * amplitude
			}
			next.push(Math.sqrt(energy / 3))
		}
		visualizer.levels = next
	}

	Process {
		id: cava

		command: ["cava", "-p", decodeURIComponent(Qt.resolvedUrl("cava.conf").toString().replace("file://", ""))]
		running: visualizer.active

		stdout: SplitParser {
			onRead: data => visualizer.updateLevels(data)
		}

		onRunningChanged: {
			if (!cava.running) visualizer.levels = [0, 0, 0, 0, 0]
		}
	}

	Connections {
		target: Pipewire

		function onDefaultAudioSinkChanged(): void {
			visualizer.levels = [0, 0, 0, 0, 0]
			// SIGUSR1 makes CAVA reopen the default output monitor.
			if (cava.running) cava.signal(10)
		}
	}

	Repeater {
		model: 5

		delegate: Rectangle {
			id: capsule

			required property int index
			readonly property int sourceBand: [3, 1, 0, 2, 4][capsule.index]
			readonly property real amplitude: Math.pow(visualizer.levels[capsule.sourceBand], 0.65)
			readonly property real maximumHeight: [13, 19, 22, 19, 13][capsule.index]

			x: (visualizer.width - 27.6) / 2 + capsule.index * 6
			y: (visualizer.height - capsule.height) / 2
			width: 3.6
			height: capsule.width + (capsule.maximumHeight - capsule.width) * capsule.amplitude
			radius: capsule.width / 2
			color: visualizer.color
			antialiasing: true
			opacity: visualizer.active ? 0.85 + 0.15 * capsule.amplitude : 0.35

			Behavior on height {
				id: response

				NumberAnimation {
					duration: !visualizer.active ? 220 : response.targetValue > capsule.height ? 35 : 140
					easing.type: Easing.OutCubic
				}
			}

			Behavior on opacity {
				NumberAnimation { duration: 160 }
			}
		}
	}
}
