import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import "../components"

PanelWindow {
	id: panel

	Theme {
		id: theme
	}

	property bool hovered: false
	property bool expanded: false
	property var wallpapers: []
	property var wallThumbs: ({})
	property var wallPreviews: ({})
	property bool wallpaperTool: false
	property string previewWallpaper: ""

	property var lyrics: []
	property bool syncedLyrics: false
	property real lookupDuration: 0
	property int activeLyric: -1
	property bool showLyrics: false
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
		} else {
			panel.contentVisible = false
			surfaceTimer.restart()
		}
	}

	function setAnchor(width: real, height: real, y: real): void {
		panel.anchorWidth = width
		panel.anchorHeight = height
		panel.anchorY = y
	}

	function wallpaperIsVideo(path): bool {
		return /\.(mp4|m4v|webm|mkv|mov|avi)$/i.test("" + path)
	}

	function wallpaperIsAnimated(path): bool {
		return /\.gif$/i.test("" + path)
	}

	function wallpaperThumb(path): string {
		var thumb = panel.wallThumbs["" + path]
		return thumb === undefined ? "" : thumb
	}

	function wallpaperPreview(path): string {
		var preview = panel.wallPreviews["" + path]
		return preview === undefined ? "" : preview
	}

	function wallpaperSource(path): string {
		if (("" + path).length === 0) return ""

		if (panel.wallpaperIsVideo(path)) {
			var preview = panel.wallpaperPreview(path)
			return preview.length > 0 ? preview : panel.wallpaperThumb(path)
		}

		return "" + path
	}

	function wallpaperSourceAnimated(path): bool {
		if (panel.wallpaperIsVideo(path)) return panel.wallpaperPreview(path).length > 0

		return panel.wallpaperIsAnimated(path)
	}

	readonly property real morphSpring: panel.expanded ? 190 : 330
	readonly property real morphDamping: panel.expanded ? 21 : 31
	property int artVersion: 0
	property string artSource: ""

	readonly property string artCachePath: Quickshell.env("HOME") + "/.cache/moxi-artwork"

	readonly property color accent: theme.accent
	readonly property color foreground: theme.foreground
	readonly property color muted: theme.muted
	readonly property color idle: theme.idle
	readonly property string fontFamily: momo.status === FontLoader.Ready ? momo.name : ""
	readonly property string symbolDir: Quickshell.env("HOME") + "/.config/quickshell/moxi/assets/symbols/"
	readonly property string glyphFont: Qt.fontFamilies().indexOf("SF Symbols") !== -1 ? "SF Symbols" : "Symbols Nerd Font"

	property real cornerRadius: panel.expanded ? 30 : panel.anchorHeight / 2
	readonly property real cornerPower: 4

	Behavior on cornerRadius {
		NumberAnimation {
			duration: panel.expanded ? 300 : 220
			easing.type: Easing.Bezier
			easing.bezierCurve: [0.32, 0.72, 0, 1]
		}
	}

	readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
	readonly property bool hasPlayer: panel.player !== null
	property bool locallyPlaying: false
	property bool hasLocalOverride: false
	readonly property bool playing: panel.hasLocalOverride
		? panel.locallyPlaying
		: (panel.hasPlayer && panel.player.playbackState === MprisPlaybackState.Playing)

	function togglePlayback(): void {
		if (!panel.hasPlayer || !panel.player.canTogglePlaying) return

		panel.locallyPlaying = !panel.playing
		panel.hasLocalOverride = true
		panel.player.togglePlaying()
	}
	readonly property string trackTitle: panel.hasPlayer && panel.player.trackTitle ? panel.player.trackTitle : ""
	readonly property string trackArtist: panel.hasPlayer && panel.player.trackArtist ? panel.player.trackArtist : ""
	readonly property string trackAlbum: panel.hasPlayer && panel.player.trackAlbum ? panel.player.trackAlbum : ""
	readonly property string trackKey: panel.trackArtist + " — " + panel.trackTitle

	readonly property real metadataLength: {
		if (!panel.hasPlayer) return 0

		var raw = panel.player.metadata["mpris:length"]
		return raw ? raw / 1000000 : 0
	}
	readonly property real trackDuration: {
		if (panel.hasPlayer && panel.player.lengthSupported && panel.player.length > 0) return panel.player.length
		if (panel.metadataLength > 0) return panel.metadataLength

		return panel.lookupDuration
	}
	property real trackPosition: 0
	property bool positionFallback: false
	property bool positionTrusted: false
	property real trustBase: -1
	property real lastReported: -1
	property int stallTicks: 0
	property bool progressFast: false
	readonly property real progress: panel.trackDuration > 0
		? Math.max(0, Math.min(1, panel.trackPosition / panel.trackDuration))
		: 0
	readonly property string artUrl: {
		if (!panel.hasPlayer) return ""

		var art = panel.player.metadata["mpris:artUrl"]
		return art ? art : ""
	}
	readonly property string trackUrl: {
		if (!panel.hasPlayer) return ""

		var url = panel.player.metadata["xesam:url"]
		return url ? url : ""
	}

	function timeText(seconds): string {
		if (!isFinite(seconds) || seconds <= 0) return "--:--"

		var total = Math.floor(seconds)
		var minutes = Math.floor(total / 60)
		var rest = total % 60

		return minutes + ":" + (rest < 10 ? "0" : "") + rest
	}

	function positionText(seconds): string {
		if (!isFinite(seconds) || seconds < 0) return "--:--"

		var total = Math.floor(seconds)
		var minutes = Math.floor(total / 60)
		var rest = total % 60

		return minutes + ":" + (rest < 10 ? "0" : "") + rest
	}

	function parseLyrics(raw): var {
		var lines = raw.split("\n")
		var result = []
		var pattern = /^\[(\d+):(\d+(?:[.:]\d+)?)\](.*)$/

		for (var i = 0; i < lines.length; ++i) {
			var match = pattern.exec(lines[i])
			if (!match) continue

			var seconds = parseInt(match[1], 10) * 60 + parseFloat(match[2].replace(":", "."))
			var text = match[3].trim()
			if (text.length === 0) continue

			result.push({ time: seconds, text: text })
		}

		return result
	}

	function applyLyrics(payload): void {
		panel.lyrics = []
		panel.syncedLyrics = false
		panel.activeLyric = -1

		if (!payload || payload.length === 0) return

		var data = null
		try {
			data = JSON.parse(payload)
		} catch (error) {
			return
		}

		if (!data) return

		if (data.duration && data.duration > 0) panel.lookupDuration = data.duration

		if (data.syncedLyrics && data.syncedLyrics.length > 0) {
			var parsed = panel.parseLyrics(data.syncedLyrics)

			if (parsed.length > 0) {
				panel.lyrics = parsed
				panel.syncedLyrics = true
				panel.showLyrics = true
				panel.updateActiveLyric()
				return
			}
		}

		if (data.plainLyrics && data.plainLyrics.length > 0) {
			panel.lyrics = data.plainLyrics.split("\n").map(function(line) {
				return { time: -1, text: line }
			})
			panel.showLyrics = true
		}
	}

	function updateActiveLyric(): void {
		if (!panel.syncedLyrics || panel.lyrics.length === 0) {
			panel.activeLyric = -1
			return
		}

		var position = panel.trackPosition
		var index = -1

		for (var i = 0; i < panel.lyrics.length; ++i) {
			if (panel.lyrics[i].time <= position) index = i
			else break
		}

		if (index !== panel.activeLyric) panel.activeLyric = index
	}

	function seekTo(seconds): void {
		if (!panel.hasPlayer || !panel.player.canSeek || !(seconds >= 0)) return

		panel.player.position = seconds
		panel.trackPosition = seconds
		panel.progressFast = true
		progressFastTimer.restart()
		panel.player.positionChanged()
		lyricsView.manual = false
		panel.updateActiveLyric()
	}

	Timer {
		id: progressFastTimer

		interval: 360
		onTriggered: panel.progressFast = false
	}

	Timer {
		id: lyricsDebounce

		interval: 700
		onTriggered: lyricsFetch.running = true
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

	FontLoader {
		id: momo
		source: "../fonts/momotrust.ttf"
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
	mask: Region { item: inputArea }

	Timer {
		interval: 250
		running: panel.hasPlayer && !panel.positionFallback
		repeat: true
		onTriggered: {
			if (!panel.player.positionSupported) {
				if (!panel.playing) return

				panel.stallTicks += 1

				if (panel.stallTicks > 8) panel.positionFallback = true

				return
			}

			panel.player.positionChanged()

			var reported = panel.player.position

			if (reported < 0) return
			if (panel.trackDuration > 0 && reported > panel.trackDuration + 1) return

			var advanced = reported > panel.lastReported + 0.05

			if (advanced) {
				panel.stallTicks = 0
			} else if (panel.playing) {
				panel.stallTicks += 1

				if (panel.stallTicks > 8) panel.positionFallback = true
			}

			if (panel.trustBase < 0) panel.trustBase = reported
			else if (reported - panel.trustBase > 0.3) panel.positionTrusted = true

			panel.lastReported = reported

			if (!panel.positionTrusted) return
			if (progressTrack.dragging) return

			var drift = reported - panel.trackPosition

			if (Math.abs(drift) > 1.5) panel.trackPosition = reported
			else if (Math.abs(drift) > 0.35) panel.trackPosition += drift * 0.5
		}
	}

	Timer {
		interval: 100
		running: panel.hasPlayer && panel.playing && !progressTrack.dragging
		repeat: true

		property double lastTick: 0

		onRunningChanged: lastTick = 0

		onTriggered: {
			var now = Date.now()

			if (lastTick === 0) {
				lastTick = now
				return
			}

			var delta = (now - lastTick) / 1000

			lastTick = now

			var next = panel.trackPosition + delta

			panel.trackPosition = panel.trackDuration > 0 ? Math.min(panel.trackDuration, next) : next
		}
	}

	Timer {
		interval: 100
		running: panel.syncedLyrics && panel.lyrics.length > 0
		repeat: true
		onTriggered: panel.updateActiveLyric()
	}

	onTrackKeyChanged: {
		panel.trackPosition = 0
		panel.positionFallback = false
		panel.positionTrusted = false
		panel.trustBase = -1
		panel.lastReported = -1
		panel.stallTicks = 0
		panel.progressFast = true
		progressFastTimer.restart()
		panel.lookupDuration = 0
		panel.lyrics = []
		panel.syncedLyrics = false
		panel.activeLyric = -1
		panel.showLyrics = false

		if (panel.trackTitle.length > 0) lyricsDebounce.restart()
		if (panel.artUrl.length > 0) artCache.running = true
	}

	onArtUrlChanged: if (panel.artUrl.length > 0) artCache.running = true

	onActiveLyricChanged: lyricsView.scrollToActive()

	Connections {
		target: panel.player

		function onPlaybackStateChanged() {
			if (!panel.hasLocalOverride) return

			var reported = panel.player.playbackState === MprisPlaybackState.Playing

			if (reported === panel.locallyPlaying) panel.hasLocalOverride = false
		}
	}

	Process {
		id: lyricsFetch

		command: [
			Quickshell.env("HOME") + "/.config/hypr/scripts/lyrics-fetch.sh",
			panel.trackArtist,
			panel.trackTitle,
			panel.trackAlbum,
			String(panel.hasPlayer && panel.player.lengthSupported ? panel.player.length : 0),
			panel.trackUrl
		]

		running: false

		stdout: SplitParser {
			onRead: (line) => panel.applyLyrics(line)
		}
	}

	Process {
		id: artCache

		command: [
			Quickshell.env("HOME") + "/.config/hypr/scripts/artwork-fetch.sh",
			panel.artUrl,
			panel.trackUrl,
			panel.trackArtist,
			panel.trackTitle,
			panel.artCachePath
		]

		onExited: (code, status) => {
			panel.artVersion = panel.artVersion + 1

			if (code === 0) panel.artSource = "file://" + panel.artCachePath + "?v=" + panel.artVersion
			else panel.artSource = panel.artUrl
		}
	}

	Process {
		id: scan

		property var found: []
		property var thumbs: ({})
		property var previews: ({})

		command: [
			"bash",
			Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-list.sh"
		]

		running: false

		stdout: SplitParser {
			onRead: (line) => {
				const fields = line.split("\t")
				const path = fields[0]

				if (path.length === 0 || scan.found.indexOf(path) !== -1) return

				scan.found = scan.found.concat([path])

				if (fields[1] && fields[1].length > 0) scan.thumbs[path] = fields[1]
				if (fields[2] && fields[2].length > 0) scan.previews[path] = fields[2]
			}
		}

		onExited: {
			panel.wallpapers = scan.found
			panel.wallThumbs = scan.thumbs
			panel.wallPreviews = scan.previews
			scan.found = []
			scan.thumbs = ({})
			scan.previews = ({})

			if (panel.wallpapers.indexOf(panel.previewWallpaper) === -1 && panel.wallpapers.length > 0)
				panel.previewWallpaper = panel.wallpapers[0]
		}
	}

	Timer {
		interval: 4000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: scan.running = true
	}

	Process {
		id: currentWallpaper

		command: ["bash", "-c", "cat \"$HOME/.cache/current-wallpaper\" 2>/dev/null || true"]
		running: true

		stdout: SplitParser {
			onRead: (line) => {
				if (line.length > 0) panel.previewWallpaper = line
			}
		}
	}

	Process {
		id: availability

		command: ["bash", "-c", "command -v awww || command -v swww || true"]
		running: true

		stdout: SplitParser {
			onRead: (line) => {
				panel.wallpaperTool = line.length > 0
			}
		}
	}

	Process {
		id: setter

		property string target: ""

		command: [Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-set.sh", setter.target]
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
			NumberAnimation { duration: panel.surfaceVisible ? 120 : 150 }
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

			visible: true
			width: cardHost.width
			height: cardHost.height

			Squircle {
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

					Layout.fillWidth: true
					Layout.fillHeight: true
					accent: panel.accent
					foreground: panel.foreground
					muted: panel.muted
					fontFamily: panel.fontFamily
				}

				Rectangle {
					Layout.fillHeight: true
					width: 1
					color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.12)
				}

				Item {
					Layout.preferredWidth: 340
					Layout.fillHeight: true

					Rectangle {
						id: mediaFrame

						anchors.top: parent.top
						anchors.horizontalCenter: parent.horizontalCenter
						width: 170
						height: 170
						color: "transparent"

						SquircleImage {
							id: artwork

							anchors.fill: parent
							anchors.margins: 2
							source: panel.artSource.length > 0 ? panel.artSource : panel.artUrl
							radius: 26
							power: 4
							sourceWidth: 400
							sourceHeight: 400
							visible: opacity > 0.01
							opacity: artwork.ready && !panel.showLyrics ? 1 : 0
							scale: panel.showLyrics ? 0.94 : 1

							Behavior on scale {
								NumberAnimation {
									duration: 320
									easing.type: Easing.OutCubic
								}
							}

							Behavior on opacity {
								NumberAnimation {
									duration: 320
									easing.type: Easing.OutCubic
								}
							}

							Connections {
								target: panel

								function onArtUrlChanged() {
									artFade.restart()
								}
							}

							SequentialAnimation {
								id: artFade

								NumberAnimation {
									target: artwork
									property: "imageScale"
									to: 0.95
									duration: 110
								}
								NumberAnimation {
									target: artwork
									property: "imageScale"
									to: 1
									duration: 190
									easing.type: Easing.OutCubic
								}
							}
						}


						ListView {
							id: lyricsView

							anchors.fill: parent
							anchors.margins: 10
							clip: true
							spacing: 5
							model: panel.lyrics
							visible: opacity > 0.01
							opacity: panel.showLyrics ? 1 : 0
							boundsBehavior: Flickable.StopAtBounds
							pixelAligned: false
							cacheBuffer: 2400
							property bool manual: false
							layer.enabled: lyricsView.opacity > 0.01
							layer.effect: MultiEffect {
								maskEnabled: true
								maskSource: lyricsSharpMask
							}

							Behavior on opacity {
								NumberAnimation {
									duration: 260
									easing.type: Easing.OutCubic
								}
							}

							function scrollToActive() {
								if (!panel.syncedLyrics || panel.activeLyric < 0 || manual) return

								var entry = itemAtIndex(panel.activeLyric)

								if (!entry) {
									scrollAnimation.to = Math.max(
										0,
										Math.min(contentHeight - height, panel.activeLyric / Math.max(1, count) * contentHeight - height / 2)
									)
									scrollAnimation.restart()
									return
								}

								scrollAnimation.to = Math.max(
									0,
									Math.min(contentHeight - height, entry.y - (height - entry.height) / 2)
								)
								scrollAnimation.restart()
							}

							function glideBy(delta): void {
								manual = true
								resumeTimer.restart()
								scrollAnimation.to = Math.max(0, Math.min(contentHeight - height, contentY + delta))
								scrollAnimation.restart()
							}

							onMovementStarted: {
								manual = true
								resumeTimer.restart()
							}

							WheelHandler {
								onWheel: (event) => {
									var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 70

									lyricsView.glideBy(-delta)
									event.accepted = true
								}
							}

							NumberAnimation {
								id: scrollAnimation

								target: lyricsView
								property: "contentY"
								duration: 620
								easing.type: Easing.InOutCubic
							}

							Timer {
								id: resumeTimer
								interval: 8000

								onTriggered: {
									lyricsView.manual = false
									lyricsView.scrollToActive()
								}
							}

							delegate: Text {
								id: lyricLine

								required property var modelData
								required property int index

								width: ListView.view.width
								text: modelData.text
								color: index === panel.activeLyric
									? panel.accent
									: lineMouse.containsMouse ? panel.foreground : panel.muted
								font.family: panel.fontFamily
								font.pixelSize: 12
								font.weight: index === panel.activeLyric ? Font.DemiBold : Font.Normal
								horizontalAlignment: Text.AlignHCenter
								wrapMode: Text.WordWrap

								Behavior on color {
									ColorAnimation { duration: 160 }
								}

								MouseArea {
									id: lineMouse

									anchors.fill: parent
									enabled: modelData.time >= 0 && panel.hasPlayer && panel.player.canSeek
									hoverEnabled: true
									cursorShape: Qt.PointingHandCursor
									onClicked: panel.seekTo(modelData.time)
								}
							}
						}

						Item {
							id: lyricsSharpMask

							anchors.fill: lyricsView
							visible: false
							layer.enabled: true

							Rectangle {
								anchors.fill: parent
								gradient: Gradient {
									GradientStop { position: 0.0; color: "#00ffffff" }
									GradientStop { position: 0.3; color: "#ffffffff" }
									GradientStop { position: 0.7; color: "#ffffffff" }
									GradientStop { position: 1.0; color: "#00ffffff" }
								}
							}
						}

						Text {
							anchors.centerIn: parent
							visible: panel.showLyrics && panel.lyrics.length === 0
							color: panel.muted
							font.family: panel.fontFamily
							font.pixelSize: 12
							text: panel.trackTitle.length > 0 ? "no lyrics found" : "nothing playing"
						}

						Text {
							anchors.centerIn: parent
							visible: !panel.showLyrics && !artwork.ready
							color: panel.muted
							font.family: panel.fontFamily
							font.pixelSize: 12
							text: panel.hasPlayer ? "no artwork" : "nothing playing"
						}

					}

					Text {
						id: title

						anchors.top: mediaFrame.bottom
						anchors.topMargin: 14
						anchors.left: parent.left
						anchors.right: parent.right
						color: panel.foreground
						elide: Text.ElideRight
						font.family: panel.fontFamily
						font.pixelSize: 15
						font.weight: Font.DemiBold
						horizontalAlignment: Text.AlignHCenter
						text: panel.trackTitle.length > 0 ? panel.trackTitle : "Nothing playing"
						wrapMode: Text.NoWrap
					}

					Text {
						id: artist

						anchors.top: title.bottom
						anchors.topMargin: 2
						anchors.left: parent.left
						anchors.right: parent.right
						color: panel.trackArtist.length > 0 ? panel.accent : panel.muted
						elide: Text.ElideRight
						font.family: panel.fontFamily
						font.pixelSize: 13
						horizontalAlignment: Text.AlignHCenter
						text: panel.trackArtist.length > 0
							? panel.trackArtist
							: (panel.trackAlbum.length > 0 ? panel.trackAlbum : "—")
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

						function seek(x): void {
							if (!panel.hasPlayer || !panel.player.canSeek || panel.trackDuration <= 0) return

							var ratio = Math.max(0, Math.min(1, x / width))

							panel.player.position = panel.trackDuration * ratio
							panel.trackPosition = panel.player.position
							panel.progressFast = true
							progressFastTimer.restart()
							panel.player.positionChanged()
							panel.updateActiveLyric()
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
							color: Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.55)

							Behavior on height {
								NumberAnimation {
									duration: 200
									easing.type: Easing.OutCubic
								}
							}
						}

						Rectangle {
							id: progressFill

							anchors.left: parent.left
							anchors.verticalCenter: parent.verticalCenter
							width: progressRail.width * panel.progress
							height: progressRail.height
							radius: height / 2
							color: panel.accent

							Behavior on width {
								enabled: !progressTrack.dragging

								NumberAnimation {
									duration: panel.progressFast ? 200 : 150
									easing.type: panel.progressFast ? Easing.OutCubic : Easing.Linear
								}
							}
						}

						Rectangle {
							id: indeterminate

							visible: panel.hasPlayer && panel.trackDuration <= 0
							y: progressRail.y
							width: progressRail.width * 0.25
							height: progressRail.height
							radius: height / 2
							color: panel.accent
							opacity: 0.6

							SequentialAnimation {
								running: indeterminate.visible
								loops: Animation.Infinite

								NumberAnimation {
									target: indeterminate
									property: "x"
									from: 0
									to: progressTrack.width - indeterminate.width
									duration: 1500
									easing.type: Easing.InOutSine
								}
								NumberAnimation {
									target: indeterminate
									property: "x"
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
							enabled: panel.hasPlayer
							hoverEnabled: true
							cursorShape: panel.player && panel.player.canSeek && panel.trackDuration > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
							onClicked: (mouse) => progressTrack.seek(mouse.x)
							onPressed: (mouse) => {
								progressTrack.dragging = true
								progressTrack.seek(mouse.x)
							}
							onReleased: progressTrack.dragging = false
							onCanceled: progressTrack.dragging = false
							onPositionChanged: (mouse) => {
								if (pressed) progressTrack.seek(mouse.x)
							}
						}
					}

					Text {
						id: elapsed

						anchors.top: progressTrack.bottom
						anchors.topMargin: 6
						anchors.left: parent.left
						color: panel.muted
						font.family: panel.fontFamily
						font.pixelSize: 11
						text: {
							if (!panel.hasPlayer) return "--:--"
							if (panel.trackDuration <= 0 && panel.trackPosition <= 0) return "live"

							return panel.positionText(panel.trackPosition)
						}
					}

					Text {
						anchors.top: progressTrack.bottom
						anchors.topMargin: 6
						anchors.right: parent.right
						color: panel.muted
						font.family: panel.fontFamily
						font.pixelSize: 11
						text: panel.timeText(panel.trackDuration)
					}

					Row {
						id: controls

						anchors.top: elapsed.bottom
						anchors.topMargin: 14
						anchors.horizontalCenter: parent.horizontalCenter
						spacing: 18

						Item {
							width: 48
							height: 48

							Rectangle {
								anchors.fill: parent
								radius: 24
								color: previousArea.containsMouse ? theme.idle : "transparent"

								Behavior on color {
									ColorAnimation { duration: 140 }
								}
							}

							Image {
								anchors.centerIn: parent
								anchors.verticalCenterOffset: 1
								width: 30
								height: 30
								source: "file://" + panel.symbolDir + "previous-fg.svg"
								sourceSize.width: 60
								sourceSize.height: 60
									layer.enabled: true
									layer.effect: MultiEffect {
										colorization: 1
										colorizationColor: theme.accent
									}
								fillMode: Image.PreserveAspectFit
								asynchronous: true
								opacity: panel.hasPlayer && panel.player.canGoPrevious ? 1 : 0.4

								Behavior on opacity {
									NumberAnimation { duration: 140 }
								}
							}

							MouseArea {
								id: previousArea

								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: if (panel.hasPlayer && panel.player.canGoPrevious) panel.player.previous()
							}
						}

						Item {
							width: 48
							height: 48

							Rectangle {
								anchors.fill: parent
								radius: 24
								color: playArea.containsMouse
									? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.3)
									: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18)

								Behavior on color {
									ColorAnimation { duration: 140 }
								}
							}

							Image {
								anchors.centerIn: parent
								anchors.horizontalCenterOffset: panel.playing ? 0 : 2
								width: 24
								height: 24
								source: "file://" + panel.symbolDir + (panel.playing ? "pause-fg.svg" : "play-fg.svg")
								sourceSize.width: 48
								sourceSize.height: 48
									layer.enabled: true
									layer.effect: MultiEffect {
										colorization: 1
										colorizationColor: theme.accent
									}
								fillMode: Image.PreserveAspectFit
								asynchronous: true
							}

							MouseArea {
								id: playArea

								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: panel.togglePlayback()
							}
						}

						Item {
							width: 48
							height: 48

							Rectangle {
								anchors.fill: parent
								radius: 24
								color: nextArea.containsMouse ? theme.idle : "transparent"

								Behavior on color {
									ColorAnimation { duration: 140 }
								}
							}

							Image {
								anchors.centerIn: parent
								anchors.verticalCenterOffset: 1
								width: 30
								height: 30
								source: "file://" + panel.symbolDir + "next-fg.svg"
								sourceSize.width: 60
								sourceSize.height: 60
									layer.enabled: true
									layer.effect: MultiEffect {
										colorization: 1
										colorizationColor: theme.accent
									}
								fillMode: Image.PreserveAspectFit
								asynchronous: true
								opacity: panel.hasPlayer && panel.player.canGoNext ? 1 : 0.4

								Behavior on opacity {
									NumberAnimation { duration: 140 }
								}
							}

							MouseArea {
								id: nextArea

								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: if (panel.hasPlayer && panel.player.canGoNext) panel.player.next()
							}
						}
					}

					Rectangle {
						id: lyricsToggle

						anchors.top: controls.bottom
						anchors.topMargin: 8
						anchors.horizontalCenter: parent.horizontalCenter
						width: 35
						height: 35
						radius: 15
						color: lyricsToggleArea.containsMouse
							? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.34)
							: panel.showLyrics
								? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.22)
								: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.78)
						visible: panel.lyrics.length > 0
						opacity: panel.expanded ? 1 : 0

						Behavior on color {
							ColorAnimation { duration: 140 }
						}

						Image {
							anchors.centerIn: parent
							anchors.verticalCenterOffset: 0.8
							width: 21
							height: 21
							source: "file://" + panel.symbolDir + "quotes-fg.svg"
							sourceSize.width: 34
							sourceSize.height: 34
							fillMode: Image.PreserveAspectFit
							asynchronous: true
							layer.enabled: true
							layer.effect: MultiEffect {
								colorization: 1
								colorizationColor: panel.accent
							}
						}

						MouseArea {
							id: lyricsToggleArea

							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: panel.showLyrics = !panel.showLyrics
						}
					}
				}

				Rectangle {
					Layout.fillHeight: true
					width: 1
					color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.12)
				}

				Item {
					Layout.preferredWidth: 250
					Layout.fillHeight: true

					Text {
						id: wallTitle

						color: panel.foreground
						font.family: panel.fontFamily
						font.pixelSize: 14
						font.weight: Font.DemiBold
						text: "Wallpaper"
					}

					Rectangle {
						id: previewFrame

						anchors.top: wallTitle.bottom
						anchors.topMargin: 10
						anchors.left: parent.left
						anchors.right: parent.right
						height: 140
						color: "transparent"

						SquircleImage {
							id: preview

							anchors.fill: parent
							source: panel.wallpaperSource(panel.previewWallpaper).length > 0 ? "file://" + panel.wallpaperSource(panel.previewWallpaper) : ""
							animated: panel.wallpaperSourceAnimated(panel.previewWallpaper)
							radius: 21
							power: 4
							sourceWidth: 560
							sourceHeight: 320

							Connections {
								target: panel

								function onPreviewWallpaperChanged() {
									previewFade.restart()
								}
							}

							SequentialAnimation {
								id: previewFade

								NumberAnimation {
									target: preview
									property: "opacity"
									to: 0.3
									duration: 80
								}
								NumberAnimation {
									target: preview
									property: "opacity"
									to: 1
									duration: 160
									easing.type: Easing.OutCubic
								}
							}
						}
					}

					GridView {
						id: grid

						anchors.top: previewFrame.bottom
						anchors.topMargin: 12
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.bottom: hint.top
						anchors.bottomMargin: 8
						clip: true
						cellWidth: 90
						cellHeight: 66
						model: panel.wallpapers

						delegate: Item {
							required property var modelData

							width: grid.cellWidth
							height: grid.cellHeight
							z: thumbMouse.containsMouse ? 2 : 1

							Rectangle {
								id: thumb

								anchors.centerIn: parent
								width: parent.width - 14
								height: parent.height - 14
								radius: 12
								color: "transparent"
								scale: thumbMouse.containsMouse ? 1.1 : 1

								Behavior on scale {
									NumberAnimation {
										duration: 190
										easing.type: Easing.Bezier
										easing.bezierCurve: [0.22, 1.12, 0.36, 1]
									}
								}

								SquircleImage {
									anchors.fill: parent
									source: "file://" + (panel.wallpaperIsVideo(modelData) ? panel.wallpaperThumb(modelData) : modelData)
									radius: 11
									power: 4
									sourceWidth: 168
									sourceHeight: 120
								}

								Rectangle {
									anchors.right: parent.right
									anchors.top: parent.top
									anchors.margins: 5
									width: panel.wallpaperIsVideo(modelData) ? 15 : 22
									height: 15
									radius: 7.5
									color: Qt.rgba(0, 0, 0, 0.55)
									visible: panel.wallpaperIsVideo(modelData) || panel.wallpaperIsAnimated(modelData)

									Shape {
										anchors.centerIn: parent
										anchors.verticalCenterOffset: -0.5
										anchors.horizontalCenterOffset: 0.6
										width: 7
										height: 8
										visible: panel.wallpaperIsVideo(modelData)
										preferredRendererType: Shape.CurveRenderer

										ShapePath {
											strokeColor: "transparent"
											fillColor: "white"
											startX: 0
											startY: 6.6
											PathLine { x: 0; y: 1.4 }
											PathQuad { controlX: 0; controlY: 0; x: 1.22; y: 0.69 }
											PathLine { x: 5.78; y: 3.31 }
											PathQuad { controlX: 7; controlY: 4; x: 5.78; y: 4.69 }
											PathLine { x: 1.22; y: 7.31 }
											PathQuad { controlX: 0; controlY: 8; x: 0; y: 6.6 }
										}
									}

									Text {
										anchors.centerIn: parent
										visible: !panel.wallpaperIsVideo(modelData)
										color: "white"
										font.family: panel.fontFamily
										font.pixelSize: 8
										font.weight: Font.Bold
										text: "GIF"
									}
								}

								Squircle {
									anchors.fill: parent
									power: 4
									radius: 12
									fillColor: "transparent"
									strokeColor: panel.accent
									strokeWidth: thumbMouse.containsMouse || panel.previewWallpaper === modelData ? 1.4 : 0
								}

								MouseArea {
									id: thumbMouse

									anchors.fill: parent
									hoverEnabled: true
									cursorShape: Qt.PointingHandCursor
									onEntered: panel.previewWallpaper = modelData
									onClicked: {
										panel.previewWallpaper = modelData
										setter.target = modelData
										setter.running = true
									}
								}
							}
						}
					}

					Text {
						id: hint

						anchors.left: parent.left
						anchors.right: parent.right
						anchors.bottom: parent.bottom
						visible: !panel.wallpaperTool
						color: theme.danger
						font.family: panel.fontFamily
						font.pixelSize: 11
						text: "install awww to set wallpapers"
					}
				}
			}
		}

		HoverHandler {
			id: cardHover
			onHoveredChanged: panel.hovered = cardHover.hovered
		}
	}

	Item {
		id: inputArea

		anchors.horizontalCenter: cardHost.horizontalCenter
		anchors.top: cardHost.top
		width: panel.expanded ? cardHost.width : 0
		height: panel.expanded ? cardHost.height : 0
	}
}
