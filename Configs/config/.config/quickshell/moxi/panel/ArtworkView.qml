pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../components"

Item {
	id: artwork

	required property ArtworkController controller
	property real lyricsFade: 0
	property real lyricsBlur: 0
	property int transportDirection: 0

	anchors.fill: parent
	anchors.margins: 2
	clip: true
	visible: opacity > 0.01
	opacity: artwork.ready ? 1 - artwork.lyricsFade : 0
	scale: 1 - 0.06 * artwork.lyricsFade
	layer.enabled: true
	layer.effect: MultiEffect {
		maskEnabled: true
		maskSource: artworkMask
		blurEnabled: artwork.lyricsBlur > 0.01
		blur: artwork.lyricsBlur
		blurMax: 20
		autoPaddingEnabled: true
	}

	Squircle {
		id: artworkMask

		anchors.fill: parent
		visible: false
		layer.enabled: true
		radius: 26
		power: 4
		fillColor: "white"
	}

	property int activeSlot: 0
	readonly property SquircleImage currentImage: activeSlot === 0 ? artworkOut : artworkIn
	readonly property SquircleImage nextImage: activeSlot === 0 ? artworkIn : artworkOut
	readonly property bool ready: currentImage.ready || (artSwap.running && nextImage.ready)
	property string shownKey: ""
	property string shown: ""
	property string incoming: ""
	property string incomingKey: ""
	property bool pending: false
	property bool animateSwap: true
	property real swapDir: 1

	function artSourceNow(): string {
		if (artwork.controller.artSource.length > 0 && artwork.controller.artSourceKey === artwork.controller.artCacheKey)
			return artwork.controller.artSource

		return artwork.shown
	}

	function swap(dir): void {
		const next = artwork.artSourceNow()
		if (next.length === 0 || (next === artwork.shown && !artwork.pending && !artSwap.running))
			return
		if (next === artwork.incoming && (artwork.pending || artSwap.running))
			return
		if (artSwap.running) {
			artSwap.stop()
			artwork.finish()
		} else if (artwork.pending) {
			artwork.cancelPending()
		}

		artwork.animateSwap = !artwork.controller.artUnchanged && artwork.shownKey !== artwork.controller.artTrackKey
		artwork.incomingKey = artwork.controller.artTrackKey
		artwork.swapDir = dir
		artwork.incoming = next
		artwork.pending = true
		artwork.nextImage.x = 0
		artwork.nextImage.opacity = 0
		artwork.nextImage.source = next
		artwork.maybeStart()
	}

	function maybeStart(): void {
		if (!artwork.pending)
			return
		if (artwork.nextImage.failed) {
			artwork.cancelPending()
			return
		}
		if (!artwork.nextImage.ready)
			return
		artwork.pending = false
		if (!artwork.animateSwap) {
			artwork.finish()
			return
		}
		artwork.currentImage.x = 0
		artwork.currentImage.opacity = 1
		artwork.nextImage.x = artwork.width * artwork.swapDir
		artwork.nextImage.opacity = 1
		artSwap.restart()
	}

	function finish(): void {
		if (!artwork.nextImage.ready)
			return
		const previous = artwork.currentImage
		artwork.activeSlot = 1 - artwork.activeSlot
		artwork.shown = artwork.currentImage.source
		artwork.shownKey = artwork.incomingKey
		artwork.currentImage.x = 0
		artwork.currentImage.opacity = 1
		// Reuse the decoded incoming image instead of reloading it into another item.
		previous.source = ""
		previous.x = 0
		previous.opacity = 0
	}

	function cancelPending(): void {
		if (artSwap.running) {
			artSwap.stop()
			artwork.finish()
		}
		artwork.pending = false
		artwork.nextImage.source = ""
		artwork.nextImage.opacity = 0
		artwork.nextImage.x = 0
		artwork.incoming = artwork.shown
		artwork.incomingKey = artwork.shownKey
	}

	function reset(): void {
		artSwap.stop()
		playerLossTimer.stop()
		artwork.pending = false
		artwork.shown = ""
		artwork.shownKey = ""
		artwork.incoming = ""
		artwork.incomingKey = ""
		artworkOut.source = ""
		artworkIn.source = ""
		artworkOut.x = 0
		artworkIn.x = 0
		artworkOut.opacity = 0
		artworkIn.opacity = 0
		artwork.controller.artSource = ""
		artwork.controller.artSourceKey = ""
		artwork.controller.artShownFile = ""
	}

	Timer {
		id: playerLossTimer
		interval: 750
		onTriggered: {
			if (!artwork.controller.media.hasPlayer)
				artwork.reset()
		}
	}

	Connections {
		target: artwork.controller

		function onArtSourceChanged() {
			if (artwork.controller.artSource.length === 0)
				return
			artwork.swap(artwork.transportDirection !== 0 ? artwork.transportDirection : 1)
		}

		function onArtFailed() {
			if (artwork.ready)
				artwork.cancelPending()
			else
				artwork.reset()
		}
	}

	Connections {
		target: artwork.controller.media

		function onHasPlayerChanged() {
			if (artwork.controller.media.hasPlayer) {
				playerLossTimer.stop()
				return
			}
			artwork.controller.artSource = ""
			artwork.controller.artSourceKey = ""
			// Browsers briefly drop their MPRIS metadata between recordings.
			playerLossTimer.restart()
		}
	}

	Connections {
		target: artworkIn
		function onReadyChanged() {
			Qt.callLater(artwork.maybeStart)
		}
		function onFailedChanged() {
			Qt.callLater(artwork.maybeStart)
		}
	}

	Connections {
		target: artworkOut
		function onReadyChanged() {
			Qt.callLater(artwork.maybeStart)
		}
		function onFailedChanged() {
			Qt.callLater(artwork.maybeStart)
		}
	}

	// The outer mask clips the frame; covers meet at a straight sliding edge.
	SquircleImage {
		id: artworkOut

		x: 0
		y: 0
		width: parent.width
		height: parent.height
		radius: 0
		power: 4
		sourceWidth: 400
		sourceHeight: 400
	}

	SquircleImage {
		id: artworkIn

		x: 0
		y: 0
		width: parent.width
		height: parent.height
		radius: 0
		power: 4
		sourceWidth: 400
		sourceHeight: 400
	}

	SequentialAnimation {
		id: artSwap

		ParallelAnimation {
			NumberAnimation {
				target: artwork.currentImage
				property: "x"
				to: -artwork.width * artwork.swapDir
				duration: 360
				easing.type: Easing.OutCubic
			}
			NumberAnimation {
				target: artwork.nextImage
				property: "x"
				from: artwork.width * artwork.swapDir
				to: 0
				duration: 360
				easing.type: Easing.OutCubic
			}
		}

		onFinished: artwork.finish()
	}
}
