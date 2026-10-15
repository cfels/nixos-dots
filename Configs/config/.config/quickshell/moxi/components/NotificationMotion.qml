import QtQuick

Item {
	id: motion
	property bool revealed: false
	property real progress: revealed ? 1 : 0
	property real horizontalExit: 0
	signal hidden()

	opacity: Math.max(0, Math.min(1, progress * 3))
	transform: [
		Scale {
			origin.x: motion.width
			origin.y: 0
			xScale: 0.98 + motion.progress * 0.02
			yScale: 0.98 + motion.progress * 0.02
		},
		Translate {
			x: (10 + motion.horizontalExit) * (1 - motion.progress)
			y: -(motion.height + 16) * (1 - motion.progress)
		}
	]
	Behavior on progress {
		SpringAnimation {
			spring: 2.8
			damping: 0.3
			mass: 1.15
			epsilon: 0.001
		}
	}
	onProgressChanged: if (!revealed && progress <= 0.001) hidden()
}
