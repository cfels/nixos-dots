import QtQuick
import "../components" as Shared
import QtQuick.Effects

Item {
	id: canvas

	property bool suspended: false
	property string outputName: "default"
	property int duration: Shared.Preferences.reducedMotion ? 0 : Shared.Preferences.value("wallpaper.revealDuration", 450)
	property int corner: 0
	property int activeSlot: 0
	property real progress: 0
	property string phase: "ready"
	property string error: ""
	property string pendingPath: ""
	property int pendingCorner: 0
	readonly property var current: activeSlot === 0 ? first : second
	readonly property var incoming: activeSlot === 0 ? second : first
	readonly property string currentPath: current.path
	readonly property bool busy: phase === "loading" || phase === "animating"
	onDurationChanged: {
		if (duration === 0 && phase === "animating") {
			reveal.stop()
			progress = 1
			finishReveal()
		}
	}

	function setWallpaper(path, origin): void {
		if (busy) {
			pendingPath = path === incoming.path ? "" : path
			pendingCorner = origin
			return
		}
		if (currentPath === path) {
			error = current.playbackError
			phase = error.length > 0 ? "failed" : "ready"
			return
		}
		error = ""
		corner = origin
		progress = 0
		phase = "loading"
		incoming.path = path
		if (incoming.ready)
			beginReveal()
	}

	function beginReveal(): void {
		if (phase !== "loading" || !incoming.ready)
			return
		loadTimeout.stop()
		if (currentPath.length === 0) {
			// A login has no outgoing wallpaper to reveal over.
			finishReveal()
			return
		}
		if (duration === 0) { finishReveal(); return }
		phase = "animating"
		reveal.restart()
	}

	function finishReveal(): void {
		const outgoing = current
		activeSlot = 1 - activeSlot
		phase = "ready"
		// Only retire the old decoder after the new wallpaper covers the screen.
		outgoing.path = ""
		if (pendingPath.length > 0) {
			const path = pendingPath
			pendingPath = ""
			setWallpaper(path, pendingCorner)
		}
	}

	function fail(message): void {
		loadTimeout.stop()
		reveal.stop()
		phase = "failed"
		incoming.path = ""
		pendingPath = ""
		error = message
		console.error("Wallpaper:", message)
	}

	onPhaseChanged: {
		if (phase === "loading")
			loadTimeout.restart()
	}

	WallpaperMedia {
		id: first
		anchors.fill: parent
		outputName: canvas.outputName
		suspended: canvas.suspended
		presentationActive: canvas.current === first && canvas.phase !== "loading"
		visible: path.length > 0
		onReadyChanged: canvas.beginReveal()
		onFailed: message => {
			if (canvas.incoming === first && canvas.busy)
				canvas.fail(message)
			else if (canvas.current === first)
				canvas.error = message
		}
	}

	WallpaperMedia {
		id: second
		anchors.fill: parent
		outputName: canvas.outputName
		suspended: canvas.suspended
		presentationActive: canvas.current === second && canvas.phase !== "loading"
		visible: path.length > 0
		onReadyChanged: canvas.beginReveal()
		onFailed: message => {
			if (canvas.incoming === second && canvas.busy)
				canvas.fail(message)
			else if (canvas.current === second)
				canvas.error = message
		}
	}

	Item {
		id: growMask
		anchors.fill: parent
		visible: false
		layer.enabled: true

		Rectangle {
			readonly property real reach: Math.sqrt(canvas.width * canvas.width + canvas.height * canvas.height) + 2
			width: 2 * reach * canvas.progress
			height: width
			radius: width / 2
			x: (canvas.corner % 2 === 1 ? canvas.width : 0) - radius
			y: (canvas.corner >= 2 ? canvas.height : 0) - radius
			color: "white"
			antialiasing: true
		}
	}

	ShaderEffectSource {
		id: incomingTexture
		anchors.fill: parent
		visible: false
		sourceItem: canvas.incoming.path.length > 0 ? canvas.incoming : null
		// Keep VideoOutput renderable while hiding its unmasked scene-graph item.
		hideSource: true
		live: true
	}

	MultiEffect {
		anchors.fill: parent
		visible: canvas.phase === "animating"
		source: incomingTexture
		maskEnabled: true
		maskSource: growMask
		autoPaddingEnabled: false
	}

	NumberAnimation {
		id: reveal
		target: canvas
		property: "progress"
		from: 0
		to: 1
		duration: canvas.duration
		easing.type: Easing.BezierSpline
		easing.bezierCurve: [0.54, 0, 0.34, 0.99, 1, 1]
		onFinished: canvas.finishReveal()
	}

	Timer {
		id: loadTimeout
		interval: 8000
		onTriggered: canvas.fail("timed out loading wallpaper: " + canvas.incoming.path)
	}
}
