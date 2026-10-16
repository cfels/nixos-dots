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

	readonly property bool ready: artworkIn.ready || artworkOut.ready
	property string shown: ""
	property string incoming: ""
	property bool pending: false
	property real swapDir: 1

	function artSourceNow(): string {
		if (artwork.controller.artSource.length > 0 && artwork.controller.artSourceKey === artwork.controller.artCacheKey)
			return artwork.controller.artSource

		return artwork.shown
	}

	function swap(dir): void {
		var next = artwork.artSourceNow()

		if (next.length === 0)
			return
		if (next === artwork.shown && !artwork.pending)
			return
		if (next === artwork.incoming)
			return
		if (artwork.pending) {
			artSwap.stop()
			artwork.pending = false
			artwork.finish()
		}

		artwork.swapDir = dir
		artwork.incoming = next
		artwork.pending = true
		artReadyTimer.restart()
		artwork.maybeStart()
	}

	function maybeStart(force): void {
		if (!artwork.pending)
			return
		if (!force && artwork.incoming.length > 0 && !artworkIn.ready)
			return
		artReadyTimer.stop()
		artwork.pending = false
		artworkOut.source = artwork.shown
		artworkOut.x = 0
		artworkOut.opacity = artwork.shown.length > 0 ? 1 : 0
		artworkIn.opacity = 1
		artworkIn.x = 170 * artwork.swapDir
		artSwap.restart()
	}

	function finish(): void {
		artwork.shown = artwork.incoming
		artworkOut.source = artwork.shown
		artworkOut.x = 0
		artworkOut.opacity = 1
		artworkIn.x = 0
		artworkIn.opacity = 1
	}

	function reset(): void {
		artSwap.stop()
		artReadyTimer.stop()
		artwork.pending = false
		artwork.shown = ""
		artwork.incoming = ""
		artworkOut.source = ""
		artworkOut.x = 0
		artworkOut.opacity = 0
		artworkIn.x = 0
		artwork.controller.artSource = ""
		artwork.controller.artSourceKey = ""
		artwork.controller.artShownFile = ""
	}

	Timer {
		id: artReadyTimer

		interval: 800
		onTriggered: artwork.maybeStart(true)
	}

	Connections {
		target: artwork.controller

		function onArtSourceChanged() {
			artwork.swap(artwork.transportDirection !== 0 ? artwork.transportDirection : 1)
		}
	}

	Connections {
		target: artwork.controller.media

		function onHasPlayerChanged() {
			if (artwork.controller.media.hasPlayer)
				return
			artwork.reset()
		}
	}

	Connections {
		target: artworkIn

		function onReadyChanged() {
			artwork.maybeStart()
		}
	}

	SquircleImage {
		id: artworkOut

		x: 0
		y: 0
		width: parent.width
		height: parent.height
		radius: 26
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
		source: artwork.incoming
		radius: 26
		power: 4
		sourceWidth: 400
		sourceHeight: 400
	}

	SequentialAnimation {
		id: artSwap

		ParallelAnimation {
			NumberAnimation {
				target: artworkOut
				property: "x"
				to: -170 * artwork.swapDir
				duration: 360
				easing.type: Easing.OutCubic
			}
			NumberAnimation {
				target: artworkIn
				property: "x"
				from: 170 * artwork.swapDir
				to: 0
				duration: 360
				easing.type: Easing.OutCubic
			}
		}

		onFinished: artwork.finish()
	}
}
