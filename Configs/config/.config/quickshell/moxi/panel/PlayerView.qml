import Quickshell
import QtQuick
import QtQuick.Effects
import "../components"

Item {
	id: playerView

	required property PlayerController media
	required property LyricsController lyricsController
	required property ArtworkController artworkController
	required property Theme theme
	required property PanelFonts fonts
	property bool expanded: false
	property alias dragging: progressTrack.dragging
	readonly property bool hovered: playHover.hovered || previousHover.hovered || nextHover.hovered || lyricsHover.hovered || trackHover.hovered || progressTrack.dragging
	readonly property string symbolDir: Quickshell.env("HOME") + "/.config/quickshell/moxi/assets/symbols/"
	implicitHeight: lyricsToggle.y + lyricsToggle.height

	function resetLyricsScroll(): void {
		lyricsView.manual = false
	}
	function scrollToActive(): void {
		lyricsView.scrollToActive()
	}

	Rectangle {
		id: mediaFrame

		anchors.top: parent.top
		anchors.horizontalCenter: parent.horizontalCenter
		width: 170
		height: 170
		color: "transparent"

		ArtworkView {
			id: artwork
			controller: playerView.artworkController
			lyricsFade: playerView.lyricsController.lyricsFade
			lyricsBlur: playerView.lyricsController.lyricsBlur
			transportDirection: playButton.transportDir
		}

		LyricsView {
			id: lyricsView
			anchors.fill: parent
			media: playerView.media
			controller: playerView.lyricsController
			theme: playerView.theme
			fonts: playerView.fonts
		}

		Text {
			anchors.centerIn: parent
			visible: opacity > 0.01
			opacity: playerView.lyricsController.showLyrics && playerView.lyricsController.lyrics.length === 0 ? playerView.lyricsController.lyricsFade : 0
			color: playerView.theme.muted
			font.family: playerView.fonts.fontFamily
			font.pixelSize: 12
			text: playerView.media.trackTitle.length > 0 ? "no lyrics found" : playerView.media.emptyPhrase
		}

		Text {
			anchors.centerIn: parent
			visible: opacity > 0.01
			opacity: artwork.ready ? 0 : 1 - playerView.lyricsController.lyricsFade
			width: parent.width - 16
			color: playerView.theme.muted
			font.family: playerView.fonts.fontFamily
			font.pixelSize: 12
			horizontalAlignment: Text.AlignHCenter
			wrapMode: Text.WordWrap
			text: playerView.media.emptyPhrase
		}
	}

	Text {
		id: title

		anchors.top: mediaFrame.bottom
		anchors.topMargin: 14
		anchors.left: parent.left
		anchors.right: parent.right
		color: playerView.theme.foreground
		elide: Text.ElideRight
		font.family: playerView.fonts.lyricFont(title.text)
		font.pixelSize: 15
		font.weight: playerView.fonts.lyricWeight(title.text, true)
		horizontalAlignment: Text.AlignHCenter
		text: playerView.media.trackTitle.length > 0 ? playerView.media.trackTitle : playerView.media.emptyPhrase
		wrapMode: Text.NoWrap
	}

	Text {
		id: artist

		anchors.top: title.bottom
		anchors.topMargin: 2
		anchors.left: parent.left
		anchors.right: parent.right
		color: playerView.media.trackArtist.length > 0 ? playerView.theme.accent : playerView.theme.muted
		elide: Text.ElideRight
		font.family: playerView.fonts.lyricFont(artist.text)
		font.pixelSize: 13
		font.weight: playerView.fonts.lyricWeight(artist.text, false)
		horizontalAlignment: Text.AlignHCenter
		text: playerView.media.trackArtist.length > 0 ? playerView.media.trackArtist : (playerView.media.trackAlbum.length > 0 ? playerView.media.trackAlbum : "—")
		wrapMode: Text.NoWrap
	}

	Item {
		id: progressTrack

		anchors.top: artist.bottom
		anchors.topMargin: 16
		anchors.left: parent.left
		anchors.right: parent.right
		height: 16

		property bool hovered: false
		property bool dragging: false
		property bool relativeSeek: false
		property real dragBase: 0
		property real dragOffset: 0
		readonly property real seekRange: 180
		readonly property bool seekable: playerView.media.hasPlayer && playerView.media.player.canSeek
		readonly property bool waiting: playerView.media.hasPlayer && !progressTrack.dragging && (playerView.lyricsController.lyricsSearching || (playerView.media.trackDuration <= 0 && playerView.media.playing))
		property real waitingMix: progressTrack.waiting ? 1 : 0
		readonly property real waitingAmount: progressTrack.dragging ? 0 : progressTrack.waitingMix
		property real displayedProgress: playerView.media.progress

		Behavior on waitingMix {
			enabled: !progressTrack.dragging

			NumberAnimation {
				duration: 420
				easing.type: Easing.BezierSpline
				easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
			}
		}

		Behavior on displayedProgress {
			enabled: !progressTrack.dragging && progressTrack.waitingMix <= 0.001

			NumberAnimation {
				duration: playerView.media.progressFast ? 200 : 150
				easing.type: playerView.media.progressFast ? Easing.OutCubic : Easing.Linear
			}
		}

		function preview(x): void {
			if (!progressTrack.dragging || !progressTrack.seekable || progressTrack.width <= 0)
				return
			var fraction = Math.max(0, Math.min(1, x / progressTrack.width))

			if (progressTrack.relativeSeek) {
				progressTrack.dragOffset = (fraction - 0.5) * progressTrack.seekRange
				playerView.media.dragPosition = Math.max(0, progressTrack.dragBase + progressTrack.dragOffset)
			} else {
				playerView.media.dragPosition = playerView.media.trackDuration * fraction
			}

			playerView.media.trackPosition = playerView.media.dragPosition
			playerView.lyricsController.updateActiveLyric()
		}

		function commit(): void {
			if (!progressTrack.seekable) {
				progressTrack.cancel()
				return
			}

			if (!progressTrack.relativeSeek) {
				playerView.media.seekTo(playerView.media.dragPosition)
			} else if (Math.abs(progressTrack.dragOffset) >= 0.5) {
				playerView.media.seekTo(playerView.media.dragPosition, progressTrack.dragOffset)
			} else {
				progressTrack.cancel()
			}
		}

		function cancel(): void {
			progressTrack.dragging = false
			progressTrack.dragOffset = 0
			playerView.media.trackPosition = progressTrack.dragBase
			playerView.media.dragPosition = progressTrack.dragBase
			playerView.lyricsController.updateActiveLyric()
		}

		HoverHandler {
			id: trackHover
			onHoveredChanged: progressTrack.hovered = trackHover.hovered
		}

		Rectangle {
			id: progressRail

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			height: progressTrack.hovered ? 10 : 5
			radius: height / 2
			color: playerView.media.trackDuration > 0 ? Qt.rgba(playerView.theme.idle.r, playerView.theme.idle.g, playerView.theme.idle.b, progressTrack.hovered ? 0.95 : 0.7) : Qt.rgba(playerView.theme.accent.r, playerView.theme.accent.g, playerView.theme.accent.b, progressTrack.hovered ? 0.5 : 0.3)

			Behavior on color {
				ColorAnimation {
					duration: 180
				}
			}

			Behavior on height {
				NumberAnimation {
					duration: 200
					easing.type: Easing.OutCubic
				}
			}
		}

		Rectangle {
			id: progressFill

			property real sweep: 0

			anchors.verticalCenter: parent.verticalCenter
			x: progressRail.width * 0.75 * progressFill.sweep * progressTrack.waitingAmount
			width: progressRail.width * (0.25 * progressTrack.waitingAmount + (progressTrack.dragging ? playerView.media.progress : progressTrack.displayedProgress) * (1 - progressTrack.waitingAmount))
			height: progressRail.height
			radius: height / 2
			color: playerView.theme.accent
			opacity: 1 - 0.4 * progressTrack.waitingAmount

			SequentialAnimation {
				running: progressTrack.waiting
				loops: Animation.Infinite

				NumberAnimation {
					target: progressFill
					property: "sweep"
					from: 0
					to: 1
					duration: 1500
					easing.type: Easing.InOutSine
				}
				NumberAnimation {
					target: progressFill
					property: "sweep"
					from: 1
					to: 0
					duration: 1500
					easing.type: Easing.InOutSine
				}
			}
		}

		MouseArea {
			anchors.fill: parent
			anchors.topMargin: -6
			anchors.bottomMargin: -6
			enabled: progressTrack.seekable
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onPressed: mouse => {
				progressTrack.relativeSeek = playerView.media.trackDuration <= 0
				progressTrack.dragBase = playerView.media.trackPosition
				progressTrack.dragOffset = 0
				progressTrack.dragging = true
				progressTrack.preview(mouse.x)
			}
			onPositionChanged: mouse => {
				if (progressTrack.dragging)
					progressTrack.preview(mouse.x)
			}
			onReleased: {
				if (!progressTrack.dragging)
					return
				progressTrack.dragging = false
				progressTrack.commit()
			}
			onCanceled: {
				if (!progressTrack.dragging)
					return
				progressTrack.cancel()
			}
		}
	}

	Text {
		id: elapsed

		anchors.top: progressTrack.bottom
		anchors.topMargin: 6
		anchors.left: parent.left
		color: progressTrack.dragging ? playerView.theme.accent : playerView.theme.muted
		font.family: playerView.fonts.fontFamily
		font.pixelSize: 11
		text: {
			if (!playerView.media.hasPlayer)
				return "--:--"
			if (playerView.media.trackDuration <= 0 && playerView.media.trackPosition <= 0)
				return "live"

			return playerView.media.positionText(playerView.media.trackPosition)
		}
	}

	Text {
		anchors.top: progressTrack.bottom
		anchors.topMargin: 6
		anchors.right: parent.right
		color: playerView.theme.muted
		font.family: playerView.fonts.fontFamily
		font.pixelSize: 11
		text: {
			if (playerView.media.trackDuration > 0)
				return playerView.media.timeText(playerView.media.trackDuration)
			if (!progressTrack.seekable)
				return "--:--"
			if (progressTrack.dragging) {
				return (progressTrack.dragOffset < 0 ? "−" : "+") + playerView.media.positionText(Math.abs(progressTrack.dragOffset))
			}
			if (!progressTrack.hovered)
				return "--:--"

			return "−" + playerView.media.timeText(progressTrack.seekRange / 2) + " / +" + playerView.media.timeText(progressTrack.seekRange / 2)
		}
	}

	Row {
		id: controls

		anchors.top: elapsed.bottom
		anchors.topMargin: 11
		anchors.horizontalCenter: parent.horizontalCenter
		spacing: 10

		Item {
			id: previousButton

			width: 56
			height: 56

			property real swipe: 0

			HoverHandler {
				id: previousHover
				cursorShape: Qt.PointingHandCursor
			}

			TapHandler {
				onTapped: {
					if (!playerView.media.hasPlayer || !playerView.media.player.canGoPrevious)
						return
					playButton.transportDir = -1
					playButton.transportAt = Date.now()
					previousSwipe.restart()
					playerView.media.player.previous()
				}
			}

			Image {
				anchors.centerIn: parent
				anchors.horizontalCenterOffset: previousButton.swipe
				width: 48
				height: 48
				source: "file://" + playerView.symbolDir + "previous-fg.svg"
				sourceSize.width: 68
				sourceSize.height: 68
				layer.enabled: true
				layer.effect: MultiEffect {
					colorization: 1
					colorizationColor: playerView.theme.accent
					autoPaddingEnabled: false
				}
				fillMode: Image.PreserveAspectFit
				asynchronous: true
				opacity: (playerView.media.hasPlayer && playerView.media.player.canGoPrevious ? 1 : 0.4) * (1 - Math.min(1, Math.abs(previousButton.swipe) / 20))
			}

			SequentialAnimation {
				id: previousSwipe

				NumberAnimation {
					target: previousButton
					property: "swipe"
					to: -20
					duration: 150
					easing.type: Easing.OutBack
				}
				PropertyAction {
					target: previousButton
					property: "swipe"
					value: 20
				}
				NumberAnimation {
					target: previousButton
					property: "swipe"
					to: 0
					duration: 300
					easing.type: Easing.OutBack
				}
				onFinished: previousButton.swipe = 0
			}
		}

		Item {
			id: playButton

			width: 56
			height: 56

			property real swipe: 0
			property real swipeDir: 1
			property int transportDir: 0
			property double transportAt: 0

			Rectangle {
				anchors.fill: parent
				radius: 28
				color: playHover.hovered ? Qt.rgba(playerView.theme.accent.r, playerView.theme.accent.g, playerView.theme.accent.b, 0.3) : Qt.rgba(playerView.theme.accent.r, playerView.theme.accent.g, playerView.theme.accent.b, 0.18)

				Behavior on color {
					ColorAnimation {
						duration: 140
					}
				}
			}

			HoverHandler {
				id: playHover
				cursorShape: Qt.PointingHandCursor
			}

			TapHandler {
				onTapped: playerView.media.togglePlayback()
			}

			Connections {
				target: playerView.media

				function onPlayingChanged(): void {
					var recent = Date.now() - playButton.transportAt < 900

					playButton.swipeDir = (recent && playButton.transportDir !== 0) ? playButton.transportDir : (playerView.media.playing ? 1 : -1)
					playSwipe.restart()
				}
			}

			SequentialAnimation {
				id: playSwipe

				NumberAnimation {
					target: playButton
					property: "swipe"
					to: playButton.swipeDir * 20
					duration: 80
					easing.type: Easing.OutBack
				}
				PropertyAction {
					target: playButton
					property: "swipe"
					value: -playButton.swipeDir * 20
				}
				NumberAnimation {
					target: playButton
					property: "swipe"
					to: 0
					duration: 140
					easing.type: Easing.OutBack
				}
				onFinished: playButton.swipe = 0
			}

			Image {
				id: playIcon

				anchors.centerIn: parent
				anchors.horizontalCenterOffset: playButton.swipe + 2.4
				opacity: 1 - Math.min(1, Math.abs(playButton.swipe) / 20)
				width: 28
				height: 28
				visible: !playerView.media.playing
				source: "file://" + playerView.symbolDir + "play-fg.svg"
				sourceSize.width: 56
				sourceSize.height: 56
				layer.enabled: true
				layer.effect: MultiEffect {
					colorization: 1
					colorizationColor: playerView.theme.accent
					autoPaddingEnabled: false
				}
				fillMode: Image.PreserveAspectFit
				asynchronous: true
			}

			Item {
				id: pauseIcon

				anchors.centerIn: parent
				anchors.horizontalCenterOffset: playButton.swipe
				width: 22
				height: 30
				visible: playerView.media.playing
				opacity: 1 - Math.min(1, Math.abs(playButton.swipe) / 20)

				Rectangle {
					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
					width: 9
					height: 30
					radius: 2
					color: playerView.theme.accent
				}

				Rectangle {
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					width: 9
					height: 30
					radius: 2
					color: playerView.theme.accent
				}
			}
		}

		Item {
			id: nextButton

			width: 56
			height: 56

			property real swipe: 0

			HoverHandler {
				id: nextHover
				cursorShape: Qt.PointingHandCursor
			}

			TapHandler {
				onTapped: {
					if (!playerView.media.hasPlayer || !playerView.media.player.canGoNext)
						return
					playButton.transportDir = 1
					playButton.transportAt = Date.now()
					nextSwipe.restart()
					playerView.media.player.next()
				}
			}

			Image {
				anchors.centerIn: parent
				anchors.horizontalCenterOffset: nextButton.swipe
				width: 48
				height: 48
				source: "file://" + playerView.symbolDir + "next-fg.svg"
				sourceSize.width: 68
				sourceSize.height: 68
				layer.enabled: true
				layer.effect: MultiEffect {
					colorization: 1
					colorizationColor: playerView.theme.accent
					autoPaddingEnabled: false
				}
				fillMode: Image.PreserveAspectFit
				asynchronous: true
				opacity: (playerView.media.hasPlayer && playerView.media.player.canGoNext ? 1 : 0.4) * (1 - Math.min(1, Math.abs(nextButton.swipe) / 20))
			}

			SequentialAnimation {
				id: nextSwipe

				NumberAnimation {
					target: nextButton
					property: "swipe"
					to: 20
					duration: 150
					easing.type: Easing.OutBack
				}
				PropertyAction {
					target: nextButton
					property: "swipe"
					value: -20
				}
				NumberAnimation {
					target: nextButton
					property: "swipe"
					to: 0
					duration: 300
					easing.type: Easing.OutBack
				}
				onFinished: nextButton.swipe = 0
			}
		}
	}

	Rectangle {
		id: lyricsToggle

		anchors.top: controls.bottom
		anchors.topMargin: 8.5
		anchors.horizontalCenter: parent.horizontalCenter
		width: 36
		height: 36
		radius: 15
		readonly property bool loading: playerView.lyricsController.lyricsSearching
		property bool pulseOn: false
		transformOrigin: Item.Center
		border.width: 1
		border.color: Qt.rgba(playerView.theme.foreground.r, playerView.theme.foreground.g, playerView.theme.foreground.b, 0.08)
		color: lyricsHover.hovered ? Qt.rgba(playerView.theme.accent.r, playerView.theme.accent.g, playerView.theme.accent.b, 0.34) : playerView.lyricsController.showLyrics && playerView.lyricsController.lyrics.length > 0 ? Qt.rgba(playerView.theme.accent.r, playerView.theme.accent.g, playerView.theme.accent.b, 0.22) : "transparent"
		visible: playerView.media.hasPlayer && (playerView.lyricsController.lyrics.length > 0 || lyricsToggle.loading)
		opacity: playerView.expanded ? (lyricsToggle.loading ? 0.75 : 1) : 0

		Behavior on opacity {
			NumberAnimation {
				duration: 260
				easing.type: Easing.OutCubic
			}
		}

		Behavior on color {
			ColorAnimation {
				duration: 160
			}
		}

		Behavior on border.color {
			ColorAnimation {
				duration: 160
			}
		}

		Timer {
			interval: 700
			repeat: true
			running: lyricsToggle.loading
			onTriggered: lyricsToggle.pulseOn = !lyricsToggle.pulseOn
		}

		NumberAnimation {
			id: lyricsReveal

			target: lyricsToggle
			property: "scale"
			from: 0.55
			to: 1
			duration: 220
			easing.type: Easing.OutBack
			easing.overshoot: 1.1
		}

		Connections {
			target: playerView.lyricsController

			function onLyricsChanged(): void {
				if (playerView.lyricsController.lyrics.length > 0)
					lyricsReveal.restart()
			}
		}

		SequentialAnimation {
			id: lyricsPop

			NumberAnimation {
				target: lyricsToggle
				property: "scale"
				to: 1.08
				duration: 80
				easing.type: Easing.OutBack
				easing.overshoot: 1.1
			}
			NumberAnimation {
				target: lyricsToggle
				property: "scale"
				to: 1
				duration: 140
				easing.type: Easing.OutBack
				easing.overshoot: 1.1
			}
		}

		Image {
			anchors.centerIn: parent
			anchors.horizontalCenterOffset: 0
			anchors.verticalCenterOffset: 2
			width: 24
			height: 24
			source: "file://" + playerView.symbolDir + "quotes-fg.svg"
			opacity: lyricsToggle.loading ? (lyricsToggle.pulseOn ? 0.35 : 0.85) : 1

			Behavior on opacity {
				NumberAnimation {
					duration: 680
					easing.type: Easing.InOutSine
				}
			}

			sourceSize.width: 34
			sourceSize.height: 34
			fillMode: Image.PreserveAspectFit
			asynchronous: true
			layer.enabled: true
			layer.effect: MultiEffect {
				colorization: 1
				colorizationColor: playerView.lyricsController.showLyrics && playerView.lyricsController.lyrics.length > 0 ? playerView.theme.accent : playerView.theme.muted
				autoPaddingEnabled: false
			}
		}

		HoverHandler {
			id: lyricsHover
			cursorShape: Qt.PointingHandCursor
		}

		TapHandler {
			onTapped: {
				lyricsPop.restart()
				playerView.lyricsController.showLyrics = !playerView.lyricsController.showLyrics
			}
		}
	}
}
