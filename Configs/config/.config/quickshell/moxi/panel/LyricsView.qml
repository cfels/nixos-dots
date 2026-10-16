import QtQuick
import QtQuick.Effects
import "../components"

Item {
	id: lyricsDisplay

	required property PlayerController media
	required property LyricsController controller
	required property Theme theme
	required property PanelFonts fonts
	property alias manual: lyricsView.manual

	function scrollToActive(): void {
		lyricsView.scrollToActive()
	}

	// Alpha mask keeps the fade transparent over the glass surface.
	Rectangle {
		id: lyricsMask
		width: lyricsView.width
		height: lyricsView.height
		visible: false
		layer.enabled: true
		gradient: Gradient {
			GradientStop {
				position: 0
				color: "transparent"
			}
			GradientStop {
				position: 0.18
				color: "white"
			}
			GradientStop {
				position: 0.82
				color: "white"
			}
			GradientStop {
				position: 1
				color: "transparent"
			}
		}
	}

	ListView {
		id: lyricsView

		anchors.top: parent.top
		anchors.bottom: parent.bottom
		anchors.topMargin: 6 + lyricsDisplay.controller.lyricsOffset
		anchors.bottomMargin: 6 - lyricsDisplay.controller.lyricsOffset
		anchors.horizontalCenter: parent.horizontalCenter
		width: 310
		transformOrigin: Item.Center
		scale: 0.92 + 0.08 * lyricsDisplay.controller.lyricsFade
		clip: true
		spacing: 4
		model: lyricsDisplay.controller.lyrics
		visible: opacity > 0.01
		opacity: lyricsDisplay.controller.lyricsFade
		boundsBehavior: Flickable.StopAtBounds
		pixelAligned: false
		cacheBuffer: 480
		property bool manual: false
		property bool returning: false
		property real scrollTarget: 0
		property real scrollPosition: scrollTarget
		property bool scrollTracking: true
		property int followIndex: -1
		property int scrollDirection: 1
		property bool flowEnabled: false
		onManualChanged: {
			if (manual) {
				returning = false
				followIndex = -1
			}
		}
		onScrollPositionChanged: if (scrollTracking)
			contentY = scrollPosition
		// Allow the first and last lines to reach the same center point.
		topMargin: height / 2
		bottomMargin: height / 2
		readonly property real minimumY: originY - topMargin
		readonly property real maximumY: Math.max(minimumY, originY + contentHeight - height + bottomMargin)
		layer.enabled: visible
		layer.effect: MultiEffect {
			maskEnabled: true
			maskSource: lyricsMask
			blurEnabled: true
			blur: lyricsDisplay.controller.lyricsBlur
			blurMax: 20
			autoPaddingEnabled: false
		}
		function scrollToActive() {
			if (!lyricsDisplay.controller.syncedLyrics || lyricsDisplay.controller.activeLyric < 0 || lyricsDisplay.controller.activeLyric >= count || manual)
				return
			if (scrollAnimation.running && followIndex === lyricsDisplay.controller.activeLyric)
				return
			var entry = itemAtIndex(lyricsDisplay.controller.activeLyric)

			if (!entry) {
				var previousY = contentY
				scrollTracking = false
				positionViewAtIndex(lyricsDisplay.controller.activeLyric, ListView.Center)
				var destination = contentY
				scrollTarget = previousY
				contentY = previousY
				scrollTracking = true
				followIndex = lyricsDisplay.controller.activeLyric
				requestScroll(destination, false)
				return
			}

			var adjacent = followIndex >= 0 && Math.abs(lyricsDisplay.controller.activeLyric - followIndex) === 1
			requestScroll(entry.y - (height - entry.height) / 2, adjacent)
			followIndex = lyricsDisplay.controller.activeLyric
		}

		function requestScroll(target, flowing): void {
			var destination = Math.max(minimumY, Math.min(maximumY, target))
			if (Math.abs(destination - scrollTarget) < 0.1 && (scrollAnimation.running || Math.abs(destination - contentY) < 0.1)) {
				if (!scrollAnimation.running)
					returning = false
				return
			}

			if (!scrollTracking || (!scrollAnimation.running && Math.abs(scrollPosition - contentY) > 0.1)) {
				scrollTracking = false
				scrollTarget = contentY
				scrollTracking = true
			}

			scrollDirection = destination >= contentY ? 1 : -1
			flowEnabled = !returning && flowing && (flowEnabled || Math.abs(contentY - scrollTarget) < 1)
			scrollAnimation.duration = returning ? Math.round(200 + 140 * Math.log(1 + Math.abs(destination - contentY) / Math.max(1, height))) : manual ? 160 : flowing ? 320 : 220
			scrollAnimation.maximumEasingTime = manual ? 80 : returning ? 150 : 160
			scrollTarget = destination
		}

		function glideBy(delta): void {
			var base = manual && scrollAnimation.running ? scrollTarget : contentY
			manual = true
			resumeTimer.restart()
			requestScroll(base + delta, false)
		}

		onCountChanged: {
			returning = false
			followIndex = -1
			flowEnabled = false
			forceLayout()
			Qt.callLater(scrollToActive)
		}
		onContentHeightChanged: Qt.callLater(scrollToActive)

		Connections {
			target: lyricsDisplay.controller
			function onShowLyricsChanged(): void {
				if (lyricsDisplay.controller.showLyrics)
					Qt.callLater(lyricsView.scrollToActive)
			}
		}

		onMovementStarted: {
			scrollTracking = false
			scrollTarget = contentY
			manual = true
			flowEnabled = false
			followIndex = -1
			resumeTimer.restart()
		}
		onMovementEnded: resumeTimer.restart()

		WheelHandler {
			onWheel: event => {
				var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 70
				if (delta === 0)
					return
				lyricsView.glideBy(-delta)
				event.accepted = true
			}
		}

		Behavior on scrollPosition {
			enabled: lyricsView.scrollTracking
			SmoothedAnimation {
				id: scrollAnimation
				duration: 320
				velocity: -1
				maximumEasingTime: 160
				reversingMode: SmoothedAnimation.Immediate
				onRunningChanged: {
					if (!running && lyricsView.scrollTracking && Math.abs(lyricsView.scrollPosition - lyricsView.scrollTarget) < 0.1) {
						lyricsView.returning = false
						Qt.callLater(lyricsView.scrollToActive)
					}
				}
			}
		}

		Timer {
			id: resumeTimer
			interval: 2200

			onTriggered: {
				if (lyricsView.moving) {
					resumeTimer.restart()
					return
				}
				lyricsView.returning = lyricsView.manual && lyricsDisplay.controller.syncedLyrics && lyricsDisplay.controller.activeLyric >= 0
				lyricsView.manual = false
				lyricsView.scrollToActive()
			}
		}

		delegate: Text {
			id: lyricLine

			required property var modelData
			required property int index
			readonly property real viewportCenter: y + lineFlow.y - lyricsView.contentY + height / 2
			readonly property bool inViewport: viewportCenter > -height / 2 - 16 && viewportCenter < lyricsView.height + height / 2 + 16
			readonly property real edgeBlur: Math.max(0, Math.min(1, 1 - Math.min(viewportCenter, lyricsView.height - viewportCenter) / 32))
			readonly property bool current: index === lyricsDisplay.controller.activeLyric
			readonly property var letters: Array.from(String(modelData.text))
			property real emphasis: current ? 1 : 0
			property real followY: lyricsView.scrollTarget
			property real letterSweep: 0

			onCurrentChanged: if (current)
				letterReveal.restart()
			Component.onCompleted: if (current)
				letterReveal.restart()

			function escaped(text): string {
				return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
			}

			function coloredText(): string {
				if (emphasis < 0.001 || lineMouse.containsMouse)
					return escaped(modelData.text)
				var result = ""
				for (var i = 0; i < letters.length; ++i) {
					// A soft front crosses the letters; line timing remains unchanged.
					var amount = emphasis * Math.max(0, Math.min(1, (letterSweep * (letters.length + 4) - i) / 4))
					var r = Math.round(255 * (lyricsDisplay.theme.muted.r + (lyricsDisplay.theme.accent.r - lyricsDisplay.theme.muted.r) * amount))
					var g = Math.round(255 * (lyricsDisplay.theme.muted.g + (lyricsDisplay.theme.accent.g - lyricsDisplay.theme.muted.g) * amount))
					var b = Math.round(255 * (lyricsDisplay.theme.muted.b + (lyricsDisplay.theme.accent.b - lyricsDisplay.theme.muted.b) * amount))
					var hex = "#" + (0x1000000 + r * 65536 + g * 256 + b).toString(16).slice(1)
					result += '<font color="' + hex + '">' + escaped(letters[i]) + '</font>'
				}
				return result
			}

			SequentialAnimation {
				id: letterReveal
				PropertyAction {
					target: lyricLine
					property: "letterSweep"
					value: 0
				}
				NumberAnimation {
					target: lyricLine
					property: "letterSweep"
					to: 1
					duration: Math.max(220, Math.min(360, lyricLine.letters.length * 7))
					easing.type: Easing.Linear
				}
			}

			Behavior on followY {
				enabled: lyricsView.flowEnabled && !lyricsView.manual
				SmoothedAnimation {
					readonly property int relativeLine: (lyricLine.index - lyricsDisplay.controller.activeLyric) * lyricsView.scrollDirection
					duration: 320 + Math.min(150, Math.max(0, relativeLine) * 32)
					velocity: -1
					maximumEasingTime: 160
					reversingMode: SmoothedAnimation.Immediate
				}
			}

			transform: Translate {
				id: lineFlow
				y: lyricsView.flowEnabled && !lyricsView.manual ? Math.max(-10, Math.min(10, lyricsView.contentY - lyricLine.followY)) : 0
			}

			// ListView owns the delegate position; inset the text instead.
			width: ListView.view.width
			leftPadding: 20
			rightPadding: 20
			text: coloredText()
			textFormat: Text.StyledText
			color: lineMouse.containsMouse ? lyricsDisplay.theme.foreground : lyricsDisplay.theme.muted
			font.family: lyricsDisplay.fonts.lyricFont(modelData.text)
			font.pixelSize: 12
			font.weight: lyricsDisplay.fonts.lyricWeight(modelData.text, false)
			horizontalAlignment: Text.AlignHCenter
			wrapMode: Text.WordWrap
			transformOrigin: Item.Center
			scale: 0.97 + 0.07 * emphasis
			opacity: 0.68 + 0.32 * emphasis

			Behavior on emphasis {
				NumberAnimation {
					duration: lyricLine.current ? 220 : 320
					easing.type: Easing.OutCubic
				}
			}

			layer.enabled: lyricsView.visible && inViewport
			layer.effect: MultiEffect {
				blurEnabled: true
				blur: lyricLine.edgeBlur * 0.6
				blurMax: 8
				shadowEnabled: true
				shadowColor: lyricsDisplay.theme.accent
				shadowBlur: 0.7
				shadowOpacity: 0.45 * lyricLine.emphasis
				shadowHorizontalOffset: 0
				shadowVerticalOffset: 0
				autoPaddingEnabled: true
			}

			MouseArea {
				id: lineMouse

				anchors.fill: parent
				enabled: modelData.time >= 0 && lyricsDisplay.media.hasPlayer && lyricsDisplay.media.player.canSeek
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: lyricsDisplay.media.seekTo(modelData.time)
			}
		}
	}
}
