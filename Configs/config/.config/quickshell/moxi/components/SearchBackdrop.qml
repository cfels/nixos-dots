pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

Item {
	id: backdrop

	required property Item view
	property bool active: false
	property real presence: active && quietTimer.running ? 0.14 : 0

	anchors.fill: view
	clip: true

	function update(): void {
		if (active) quietTimer.restart()
	}

	onActiveChanged: if (!active) quietTimer.stop()

	Behavior on presence {
		enabled: backdrop.active
		NumberAnimation {
			duration: quietTimer.running ? 90 : 180
			easing.type: Easing.OutCubic
		}
	}

	Timer {
		id: quietTimer
		interval: 140
	}

	Loader {
		anchors.fill: parent
		active: backdrop.active && backdrop.presence > 0.001
		sourceComponent: MultiEffect {
			source: backdrop.view
			opacity: backdrop.presence
			blurEnabled: true
			blurMax: 12
			blur: 0.45
			autoPaddingEnabled: false
		}
	}
}
