pragma ComponentBehavior: Bound

import QtQuick

Item {
	id: scroll
	required property Flickable view
	property real step: 100
	signal scrolled
	anchors.fill: parent

	function bounded(value): real {
		const minimum = view.originY - view.topMargin
		const maximum = Math.max(minimum, view.originY + view.contentHeight - view.height + view.bottomMargin)
		return Math.max(minimum, Math.min(maximum, value))
	}

	WheelHandler {
		target: null
		onWheel: event => {
			if (!event.pixelDelta.y && !event.angleDelta.y) {
				event.accepted = false
				return
			}
			scroll.scrolled()
			const base = motion.running ? motion.to : scroll.view.contentY
			motion.stop()
			scroll.view.cancelFlick()
			if (event.pixelDelta.y) {
				// Trackpads already provide a smooth stream of pixel deltas.
				scroll.view.contentY = scroll.bounded(scroll.view.contentY - event.pixelDelta.y)
			} else {
				motion.from = scroll.view.contentY
				motion.to = scroll.bounded(base - event.angleDelta.y / 120 * scroll.step)
				motion.start()
			}
			event.accepted = true
		}
	}

	NumberAnimation {
		id: motion
		target: scroll.view
		property: "contentY"
		duration: Preferences.motion(120)
		easing.type: Easing.OutCubic
	}
	Connections {
		target: scroll.view
		function onMovementStarted(): void {
			motion.stop()
		}
		function onVisibleChanged(): void {
			if (!scroll.view.visible)
				motion.stop()
		}
	}
}
