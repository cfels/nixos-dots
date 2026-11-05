pragma ComponentBehavior: Bound
import QtQuick
import "../components"

Item {
	id: crossover
	property alias contentHost: livePage
	property real progress: 1
	property int direction: 1
	property bool capturing: false
	property int generation: 0
	property var snapshot: null
	property var captureChange: null
	property var pendingChange: null
	property int pendingDirection: 1
	readonly property bool busy: capturing || spring.running
	readonly property real distance: Math.min(180, width * 0.25)
	readonly property real blend: Math.max(0, Math.min(1, progress))
	clip: true

	function change(action, origin) {
		if (busy) {
			pendingChange = action
			pendingDirection = origin
			return
		}
		if (Preferences.reducedMotion || !visible || width < 1 || height < 1) {
			action()
			return
		}
		capturing = true
		captureChange = action
		direction = origin < 0 ? -1 : 1
		const serial = ++generation
		// Freeze only the outgoing pixels. Audio and wallpaper pages are never
		// duplicated, and this in-memory image is released when the spring settles.
		if (!livePage.grabToImage(result => {
			if (serial !== crossover.generation)
				return
			crossover.snapshot = result
			ghost.source = result.url
			const apply = crossover.captureChange
			crossover.captureChange = null
			apply()
			crossover.progress = 0
			crossover.capturing = false
			spring.start()
		})) {
			captureChange = null
			capturing = false
			action()
		}
	}
	function finish() {
		++generation
		spring.stop()
		progress = 1
		ghost.source = ""
		snapshot = null
		capturing = false
		const next = pendingChange || captureChange
		const origin = pendingDirection
		pendingChange = null
		captureChange = null
		if (next)
			Qt.callLater(function () {
				crossover.change(next, origin)
			})
	}
	Connections {
		target: Preferences
		function onReducedMotionChanged() {
			if (Preferences.reducedMotion)
				crossover.finish()
		}
	}
	SpringAnimation {
		id: spring
		target: crossover
		property: "progress"
		from: 0
		to: 1
		// Match the panel's slightly faster original spring.
		spring: 4.39
		damping: 0.3981
		mass: 0.6
		epsilon: 0.004
		onFinished: crossover.finish()
	}
	Timer {
		interval: 567
		running: spring.running
		onTriggered: crossover.finish()
	}
	Item {
		id: livePage
		width: crossover.width
		height: crossover.height
		x: crossover.direction * crossover.distance * (1 - crossover.progress)
		opacity: crossover.blend
		enabled: !crossover.capturing
	}
	Image {
		id: ghost
		width: crossover.width
		height: crossover.height
		x: -crossover.direction * crossover.distance * crossover.progress
		opacity: 1 - crossover.blend
		visible: source.toString().length > 0
		cache: false
	}
}
