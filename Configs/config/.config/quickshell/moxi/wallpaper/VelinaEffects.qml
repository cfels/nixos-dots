pragma ComponentBehavior: Bound
import QtQuick

Item {
	id: effects

	property url leafTexture: ""
	property string quality: "high"
	property bool running: false
	property real openingPosition: 0
	property bool opening: false
	property real seconds: 0
	property real timelinePosition: 0
	onTimelinePositionChanged: seconds = timelinePosition / 1000
	readonly property real entrance: opening ? Math.max(0, Math.min(1, (openingPosition - 766.6667) / 250)) : 1
	clip: true

	// The videos contain the UI leaf/flower tracks, but omit the particle systems.
	// Reuse their extracted leaf sprite; keep this light layer outside the video.
	FrameAnimation {
		running: effects.running && effects.quality !== "off"
		onTriggered: effects.seconds += frameTime
	}

	Repeater {
		model: effects.quality === "off" ? 0 : effects.quality === "low" ? 3 : 7
		Image {
			required property int index
			readonly property real phase: (effects.seconds / (9 + index * 1.37) + index * 0.173) % 1
			source: effects.leafTexture
			width: (18 + index % 3 * 12) * effects.width / 1920
			height: width
			x: effects.width * ((index * 0.237 + phase * 0.17) % 1)
			y: effects.height * (1.1 - phase * 1.3)
			rotation: index * 57 + phase * 120
			opacity: Math.sin(phase * Math.PI) * 0.32 * effects.entrance
			fillMode: Image.PreserveAspectFit
			asynchronous: true
		}
	}
}
