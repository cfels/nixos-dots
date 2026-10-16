pragma ComponentBehavior: Bound
import QtQuick

Item {
	id: preview

	property url source
	property color textColor: "#cdd6f4"
	property string fontFamily
	property int front: -1
	property int loading: -1
	property int stackOrder: 0
	property string failedSource: ""
	property bool initialized: false
	property bool active: true
	readonly property var frontFrame: front < 0 ? null : frame(front)
	readonly property bool waiting: !frontFrame || String(frontFrame.image.source) !== String(source)
	clip: true

	function frame(index): Item {
		return frames.itemAt(index)
	}

	function activateFrame(index): void {
		var next = frame(index)
		// A frame that is already fading keeps its depth when reversing.
		// New images enter above the currently visible composition.
		if (next.presence <= 0.001) next.stackOrder = ++stackOrder
		front = index
		loading = -1
		failedSource = ""
		for (var i = 0; i < frames.count; ++i) frame(i).active = i === index
	}

	function loadSource(): void {
		if (!initialized || !active) return
		if (!String(source).length) return
		if (frontFrame && String(frontFrame.image.source) === String(source)) {
			loading = -1
			return
		}
		if (failedSource === String(source)) return
		var nextIndex = -1
		for (var i = 0; i < frames.count; ++i) {
			var candidate = frame(i)
			if (String(candidate.image.source) === String(source)
				&& candidate.image.status === Image.Ready) {
				activateFrame(i)
				return
			}
			if (nextIndex < 0 && !candidate.active && candidate.presence <= 0.001) nextIndex = i
		}
		// A small pool lets the latest image load while earlier images fade.
		// No visible texture is replaced, even during rapid navigation.
		if (nextIndex < 0) return
		loading = nextIndex
		var next = frame(loading)
		next.image.source = source
		imageLoaded(nextIndex)
	}

	function imageLoaded(index): void {
		if (!initialized || index < 0 || index !== loading) return
		var next = frame(index)
		if (String(next.image.source) !== String(source)) return
		if (next.image.status === Image.Error) {
			failedSource = String(source)
			loading = -1
		} else if (next.image.status === Image.Ready) {
			activateFrame(index)
		}
	}

	onSourceChanged: {
		failedSource = ""
		loadSource()
	}
	onActiveChanged: if (active) loadSource()
	Component.onCompleted: {
		initialized = true
		loadSource()
	}
	Component.onDestruction: initialized = false

	Timer {
		interval: 30000
		running: !preview.active
		onTriggered: {
			preview.initialized = false
			preview.front = -1
			preview.loading = -1
			preview.failedSource = ""
			for (var i = 0; i < frames.count; ++i) {
				var cached = preview.frame(i)
				cached.active = false
				cached.image.source = ""
			}
			preview.initialized = true
		}
	}

	component Frame: Item {
		id: layer
		required property int slot
		property alias image: picture
		property bool active: false
		property real presence: active ? 1 : 0
		property int stackOrder: 0
		anchors.fill: parent
		opacity: Math.max(0, Math.min(1, presence))
		visible: presence > 0.001
		z: stackOrder
		Behavior on presence {
			SmoothedAnimation { duration: 300; velocity: -1; reversingMode: SmoothedAnimation.Eased }
		}
		onPresenceChanged: if (!active && presence <= 0.001) preview.loadSource()

		Image {
			id: picture
			anchors.fill: parent
			anchors.bottomMargin: 30
			fillMode: Image.PreserveAspectFit
			asynchronous: true
			cache: false
			onStatusChanged: preview.imageLoaded(layer.slot)
		}
		Text {
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			anchors.bottomMargin: 3
			text: picture.sourceSize.width + " × " + picture.sourceSize.height
			color: preview.textColor
			font.family: preview.fontFamily
			font.pixelSize: 11
		}
	}

	Repeater {
		id: frames
		model: 5
		delegate: Frame {
			required property int index
			slot: index
		}
	}

	Text {
		anchors.centerIn: parent
		visible: preview.front < 0
		text: preview.failedSource.length ? "Preview unavailable" : "Loading image…"
		color: preview.textColor
		font.family: preview.fontFamily
		font.pixelSize: 12
	}
	Text {
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.bottom: parent.bottom
		anchors.bottomMargin: 30
		visible: preview.front >= 0 && preview.waiting && String(preview.source).length > 0
		text: preview.failedSource.length ? "Preview unavailable" : "Loading image…"
		color: preview.textColor
		font.family: preview.fontFamily
		font.pixelSize: 11
	}
}
