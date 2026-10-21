import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components"

PanelWindow {
	id: panel

	PanelFonts {
		id: fonts
	}

	LyricsController {
		id: lyricsController
		media: playerController
		onActiveLyricChanged: playerView.scrollToActive()
	}

	ArtworkController {
		id: artworkController
		media: playerController
	}

	PlayerController {
		id: playerController
		expanded: panel.expanded
		dragging: playerView.dragging
		lookupDuration: lyricsController.lookupDuration
		onSeeked: {
			playerView.resetLyricsScroll()
			lyricsController.updateActiveLyric()
		}
		onTrackPositionChanged: lyricsController.updateActiveLyric()

		onPositionTrustedChanged: lyricsController.updateActiveLyric()

		onTrackKeyChanged: panel.syncTrack()
		onArtUrlChanged: artworkController.scheduleArt(80)
	}

	function syncTrack(): void {
		var key = playerController.trackKey

		if (key === lyricsController.lyricsKey)
			return
		lyricsController.lyricsKey = key
		playerView.dragging = false
		playerController.resetPosition()
		lyricsController.resetTrack()
		playerView.resetLyricsScroll()
		lyricsController.forgetMissingLyrics()

		if (playerController.trackTitle.length > 0)
			lyricsController.scheduleFetch()
		artworkController.scheduleArt(80)
	}

	Component.onCompleted: Qt.callLater(panel.syncTrack)

	WallpaperController {
		id: wallpaperController
		expanded: panel.expanded
	}

	Theme {
		id: theme
	}

	readonly property bool hovered: cardHover.hovered || playerView.hovered || wallpaperView.hovered
	property bool expanded: false
	property var surfaceHost: null
	visible: surfaceHost === null

	property bool contentVisible: false
	property bool surfaceVisible: false
	property real anchorWidth: 210
	property real anchorHeight: 38
	property real anchorY: 4

	onExpandedChanged: {
		if (panel.expanded) {
			surfaceTimer.stop()
			panel.surfaceVisible = true
			contentTimer.restart()

			playerController.rollEmptyPhrase()
			lyricsController.updateActiveLyric()
			lyricsController.retryLyrics()
		} else {
			calendar.selectedDay = 0
			panel.contentVisible = false
			wallpaperController.hoveredWallpaper = ""
			surfaceTimer.restart()
		}
	}

	function setAnchor(width: real, height: real, y: real): void {
		panel.anchorWidth = width
		panel.anchorHeight = height
		panel.anchorY = y
	}

	property real cornerRadius: panel.expanded ? 30 : panel.anchorHeight / 2
	readonly property real cornerPower: 4

	readonly property real playerSideWidth: Math.max(180, Math.round((layout.width - 422) / 2))

	Behavior on cornerRadius {
		NumberAnimation {
			duration: panel.expanded ? 240 : 150
			easing.type: Easing.Bezier
			easing.bezierCurve: [0.32, 0.72, 0, 1]
		}
	}

	Timer {
		id: contentTimer
		interval: 140
		onTriggered: panel.contentVisible = true
	}

	Timer {
		id: surfaceTimer
		interval: 210
		onTriggered: panel.surfaceVisible = false
	}

	anchors {
		top: true
		left: true
		right: true
	}

	margins.top: 6
	implicitHeight: 490
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	mask: Region {
		item: inputArea
	}

	Item {
		id: cardHost

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		y: panel.expanded ? 50 : panel.anchorY
		width: panel.expanded ? 920 : panel.anchorWidth
		height: panel.expanded ? 420 : panel.anchorHeight
		opacity: panel.surfaceVisible ? 1 : 0

		Behavior on opacity {
			NumberAnimation {
				duration: panel.surfaceVisible ? 120 : 150
			}
		}

		Behavior on y {
			NumberAnimation {
				duration: panel.expanded ? 300 : 220
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.32, 0.72, 0, 1]
			}
		}

		Behavior on width {
			NumberAnimation {
				duration: panel.expanded ? 300 : 220
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.32, 0.72, 0, 1]
			}
		}

		Behavior on height {
			NumberAnimation {
				duration: panel.expanded ? 300 : 220
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.32, 0.72, 0, 1]
			}
		}

		Item {
			id: cardSource

			parent: panel.surfaceHost || cardHost
			visible: true
			width: parent.width
			height: parent.height

			HoverHandler {
				id: cardHover
				blocking: false
			}

			Squircle {
				visible: !panel.surfaceHost
				anchors.fill: parent
				power: panel.cornerPower
				radius: panel.cornerRadius
				fillColor: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.7)
				strokeColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.24)
				strokeWidth: 1
			}

			RowLayout {
				id: layout

				anchors.fill: parent
				anchors.margins: 20
				spacing: 20
				opacity: panel.contentVisible ? 1 : 0

				Behavior on opacity {
					NumberAnimation {
						duration: 150
						easing.type: Easing.OutCubic
					}
				}

				Calendar {
					id: calendar

					Layout.preferredWidth: panel.playerSideWidth
					Layout.fillHeight: true
					accent: theme.accent
					foreground: theme.foreground
					muted: theme.muted
					fontFamily: fonts.fontFamily
				}

				Rectangle {
					Layout.fillHeight: true
					width: 1
					color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.12)
				}

				PlayerView {
					id: playerView

					Layout.preferredWidth: 340
					Layout.minimumWidth: 340
					Layout.maximumWidth: 340
					Layout.preferredHeight: playerView.implicitHeight
					Layout.alignment: Qt.AlignVCenter
					media: playerController
					lyricsController: lyricsController
					artworkController: artworkController
					theme: theme
					fonts: fonts
					expanded: panel.expanded
				}

				Rectangle {
					Layout.fillHeight: true
					width: 1
					color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.12)
				}

				WallpaperView {
					id: wallpaperView

					Layout.preferredWidth: panel.playerSideWidth
					Layout.fillHeight: true
					controller: wallpaperController
					theme: theme
					fontFamily: fonts.fontFamily
				}
			}
		}
	}

	Item {
		id: inputArea

		anchors.horizontalCenter: cardHost.horizontalCenter
		anchors.top: parent.top
		width: panel.expanded ? cardHost.width : 0
		height: panel.expanded ? cardHost.y + cardHost.height : 0
	}
}
