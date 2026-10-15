import QtQuick

Item {
	id: reveal

	property bool revealed: false
	property real progress: revealed ? 1 : 0
	signal hidden()

	function hideImmediately(): void {
		if (revealed) return
		motion.enabled = false
		progress = 0
		progress = Qt.binding(function() { return reveal.revealed ? 1 : 0 })
		motion.enabled = true
	}

	opacity: Math.max(0, Math.min(1, progress * 2))
	transform: [
		Scale {
			origin.x: reveal.width / 2
			origin.y: 0
			xScale: 0.65 + reveal.progress * 0.35
			yScale: 0.18 + reveal.progress * 0.82
		},
		Translate { y: -(reveal.height + 8) * (1 - reveal.progress) }
	]

	Behavior on progress {
		id: motion
		NumberAnimation {
			id: animation
			duration: motion.targetValue > reveal.progress ? 520 : 380
			easing.type: motion.targetValue > reveal.progress ? Easing.OutBack : Easing.InBack
			easing.overshoot: 0.7
		}
	}

	onProgressChanged: {
		if (!revealed && progress <= 0.001) hidden()
	}
}
