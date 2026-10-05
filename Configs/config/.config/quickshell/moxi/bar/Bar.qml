import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../components"

PanelWindow {
	id: bar

	Theme {
		id: theme
	}

	signal panelRequested()

	property bool flash: false
	property bool panelOpen: false
	property bool hovered: pillHover.hovered
	property bool held: false
	property bool holdHandled: false
	property bool expanded: bar.hovered || bar.flash || mediaPulse.running || volumeTimer.running
	property bool pillShown: true
	property bool volumeVisible: bar.audioReady && volumeTimer.running
	property real titleWidth: 170
	property real mediaWidth: bar.hasPlayer ? mediaRow.implicitWidth : 0
	property real volumeWidth: bar.volumeVisible ? volumeRow.implicitWidth : 0
	property real dateWidth: bar.hovered ? dateLabel.implicitWidth : 0
	readonly property real pillWidth: pill.width * pill.scale
	readonly property real pillHeight: pill.height * pill.scale
	readonly property real pillTop: pill.y - pill.height * (pill.scale - 1) / 2
	readonly property real barTopMargin: 6
	readonly property real pillScreenTop: bar.barTopMargin + bar.pillTop
	property real contentBlur: bar.pillShown ? 0 : 0.62
	property bool intro: false
	property bool audioReady: false
	property bool notificationsMuted: false

	signal notificationsToggle()

	Component.onCompleted: introTimer.restart()

	onPanelOpenChanged: {
		if (bar.panelOpen) {
			pillReturn.stop()
			bar.pillShown = false
		} else {
			bar.held = false
			pillReturn.restart()
		}
	}

	readonly property color accent: theme.accent
	readonly property color foreground: theme.foreground
	readonly property color muted: theme.muted
	readonly property color idle: theme.idle
	readonly property string fontFamily: momo.status === FontLoader.Ready ? momo.name : ""
	readonly property string cyrillicFont: ruFont.status === FontLoader.Ready ? ruFont.name : bar.fontFamily
	readonly property string japaneseFont: jpFont.status === FontLoader.Ready ? jpFont.name : bar.fontFamily
	readonly property string koreanFont: krFont.status === FontLoader.Ready ? krFont.name : bar.fontFamily
	readonly property string glyphFont: Qt.fontFamilies().indexOf("Symbols Nerd Font") !== -1 ? "Symbols Nerd Font" : ""

	function songFont(text): string {
		var value = "" + text

		if (/[\uAC00-\uD7A3\u1100-\u11FF\u3130-\u318F]/.test(value)) return bar.koreanFont
		if (/[\u3040-\u30FF\u31F0-\u31FF\u4E00-\u9FFF\uF900-\uFAFF]/.test(value)) return bar.japaneseFont
		if (/[\u0400-\u04FF\u0500-\u052F]/.test(value)) return bar.cyrillicFont

		return bar.fontFamily
	}

	function songWeight(text): int {
		return bar.songFont(text) !== bar.fontFamily ? Font.ExtraBold : Font.Normal
	}

	readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
	readonly property bool hasPlayer: bar.player !== null
	readonly property bool playing: bar.hasPlayer && bar.player.playbackState === MprisPlaybackState.Playing
	readonly property string track: {
		if (!bar.hasPlayer) return ""

		var title = (bar.player.trackTitle || "").trim()
		if (title.length > 0) return title

		return (bar.player.identity || "unknown").trim()
	}

	readonly property string artist: {
		if (!bar.hasPlayer) return ""

		return (bar.player.trackArtist || "").trim()
	}

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property var sinkAudio: bar.sink ? bar.sink.audio : null
	readonly property bool sinkMuted: bar.sinkAudio ? bar.sinkAudio.muted : false
	readonly property real sinkVolume: bar.sinkAudio ? Math.max(0, Math.min(1, bar.sinkAudio.volume)) : 0

	Behavior on titleWidth {
		NumberAnimation {
			duration: 320
			easing.type: Easing.Bezier
			easing.bezierCurve: [0.25, 1, 0.3, 1]
		}
	}

	Behavior on mediaWidth {
		NumberAnimation {
			duration: 320
			easing.type: Easing.Bezier
			easing.bezierCurve: [0.25, 1, 0.3, 1]
		}
	}

	Behavior on volumeWidth {
		NumberAnimation {
			duration: 320
			easing.type: Easing.Bezier
			easing.bezierCurve: [0.25, 1, 0.3, 1]
		}
	}

	Behavior on dateWidth {
		NumberAnimation {
			duration: 160
			easing.type: Easing.Bezier
			easing.bezierCurve: [0.25, 1, 0.3, 1]
		}
	}

	Behavior on contentBlur {
		NumberAnimation {
			duration: bar.pillShown ? 200 : 150
			easing.type: Easing.Bezier
			easing.bezierCurve: [0.32, 0.72, 0, 1]
		}
	}

	FontLoader {
		id: momo
		source: "../fonts/momotrust.ttf"
	}

	FontLoader {
		id: ruFont
		source: "../fonts/NotoSans-ExtraBold-RU.ttf"
	}

	FontLoader {
		id: jpFont
		source: "../fonts/NotoSansJP-ExtraBold.ttf"
	}

	FontLoader {
		id: krFont
		source: "../fonts/NotoSansKR-ExtraBold.ttf"
	}

	PwObjectTracker {
		objects: [bar.sink]
	}

	anchors {
		top: true
		left: true
		right: true
	}

	margins.top: bar.barTopMargin
	implicitHeight: 46
	WlrLayershell.layer: WlrLayer.Top
	exclusionMode: ExclusionMode.Auto
	color: "transparent"
	mask: Region { item: bar.pillShown ? pill : pillHidden }

	SystemClock {
		id: clock
		precision: SystemClock.Seconds
	}

	Timer {
		id: mediaPulse
		interval: 6000
	}

	Timer {
		id: volumeTimer
		interval: 1600
	}

	Timer {
		id: holdTimer
		interval: 420

		onTriggered: {
			bar.held = true
			bar.holdHandled = true
			bar.panelRequested()
		}
	}

	Timer {
		id: pillReturn
		interval: 190
		onTriggered: bar.pillShown = true
	}

	Timer {
		id: introTimer
		interval: 90
		onTriggered: bar.intro = true
	}

	Timer {
		id: audioReadyTimer
		interval: 2000
		running: true
		onTriggered: bar.audioReady = true
	}

	Process {
		id: volumePanel

		command: ["pavucontrol"]
	}

	Connections {
		target: bar.player

		function onTrackTitleChanged() {
			if (bar.playing) mediaPulse.restart()
		}

		function onPlaybackStateChanged() {
			if (bar.playing) mediaPulse.restart()
		}
	}

	Connections {
		target: bar.sinkAudio

		function onVolumesChanged() {
			if (bar.audioReady) volumeTimer.restart()
		}

		function onMutedChanged() {
			if (bar.audioReady) volumeTimer.restart()
		}
	}

	Item {
		id: pillHidden

		width: 0
		height: 0
	}

	Rectangle {
		id: pill

		anchors.centerIn: parent
		height: 38
		width: content.implicitWidth + 30
		radius: height / 2
		clip: true
		opacity: bar.intro ? 1 : 0

		transform: Translate {
			y: bar.intro ? 0 : -12

			Behavior on y {
				NumberAnimation {
					duration: 280
					easing.type: Easing.Bezier
					easing.bezierCurve: [0.32, 0.72, 0, 1]
			}
			}
		}

		Behavior on opacity {
			NumberAnimation {
				duration: 280
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.32, 0.72, 0, 1]
			}
		}

		color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, bar.pillShown ? (bar.hovered ? 0.78 : 0.66) : 0)
		border.width: 1
		border.color: bar.flash
			? bar.accent
			: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, bar.pillShown ? (bar.expanded ? 0.5 : 0.16) : 0)
		scale: bar.held ? 1.04 : 1

		Behavior on scale {
			NumberAnimation {
				duration: bar.held ? 190 : 150
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.32, 0.72, 0, 1]
			}
		}

		Behavior on color {
			ColorAnimation { duration: bar.pillShown ? 200 : 110 }
		}

		Behavior on border.color {
			ColorAnimation { duration: bar.pillShown ? 200 : 110 }
		}

		HoverHandler {
			id: pillHover
			enabled: bar.pillShown
			onHoveredChanged: if (!pillHover.hovered && !pillMouse.pressed) bar.held = false
		}

		MouseArea {
			id: pillMouse

			anchors.fill: parent
			enabled: bar.pillShown
			acceptedButtons: Qt.LeftButton | Qt.RightButton

			onPressed: (mouse) => {
				if (mouse.button === Qt.RightButton) return

				bar.held = false
				bar.holdHandled = false
				holdTimer.restart()
			}

			onReleased: (mouse) => {
				if (mouse.button === Qt.RightButton) {
					volumePanel.running = true
					return
				}

				holdTimer.stop()

				if (bar.held || bar.holdHandled || bar.panelOpen) {
					bar.held = false
					return
				}

				if (bar.hasPlayer && bar.player.canTogglePlaying) bar.player.togglePlaying()
			}

			onWheel: (wheel) => {
				if (!bar.sinkAudio) return

				var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
				var next = Math.max(0, Math.min(1, bar.sinkVolume + step))

				bar.sinkAudio.muted = false
				bar.sinkAudio.volume = next
			}

			onCanceled: holdTimer.stop()
		}

		RowLayout {
			id: content

			anchors.centerIn: parent
			spacing: 7
			scale: bar.pillShown ? 1 : 0.93
			opacity: bar.pillShown ? 1 : 0
			layer.enabled: bar.contentBlur > 0.004

			layer.effect: MultiEffect {
				blurEnabled: true
				blurMax: 26
				blur: bar.contentBlur
			}

			Behavior on scale {
				NumberAnimation {
					duration: bar.pillShown ? 200 : 170
					easing.type: Easing.Bezier
					easing.bezierCurve: [0.32, 0.72, 0, 1]
				}
			}

			Behavior on opacity {
				NumberAnimation {
					duration: bar.pillShown ? 170 : 150
					easing.type: Easing.Bezier
					easing.bezierCurve: [0.32, 0.72, 0, 1]
				}
			}

			Row {
				Layout.alignment: Qt.AlignVCenter
				spacing: 5

				Repeater {
					model: Hyprland.workspaces

					delegate: Rectangle {
						id: workspace

						required property var modelData

						height: 8
						radius: 4
						width: workspace.modelData.focused ? 22 : 8
						color: workspace.modelData.focused
							? bar.accent
							: workspace.modelData.urgent
								? theme.danger
								: workspace.modelData.active
									? bar.muted
									: bar.idle

						Behavior on width {
							NumberAnimation {
								duration: 140
								easing.type: Easing.OutCubic
							}
						}

						Behavior on color {
							ColorAnimation { duration: 140 }
						}

						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor
							onClicked: Hyprland.dispatch(
								Hyprland.usingLua
									? "hl.dsp.focus({ workspace = \"" + workspace.modelData.name + "\" })"
									: "workspace " + workspace.modelData.id
							)
						}
					}
				}
			}
			Rectangle {
				Layout.alignment: Qt.AlignVCenter
				width: 1
				height: 15
				color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16)
			}

			Text {
				Layout.alignment: Qt.AlignVCenter
				color: bar.foreground
				font.family: bar.fontFamily
				font.pixelSize: 14
				font.weight: Font.Medium
				text: Qt.formatDateTime(clock.date, "HH:mm")
			}

			Item {
				Layout.alignment: Qt.AlignVCenter
				Layout.preferredWidth: 16
				Layout.preferredHeight: 16

				Text {
					anchors.centerIn: parent
					color: bellArea.containsMouse
						? bar.foreground
						: bar.notificationsMuted
							? bar.muted
							: bar.accent
					font.family: bar.glyphFont
					font.pixelSize: 13
					text: bar.notificationsMuted ? "\u{f1f6}" : "\u{f0f3}"

					Behavior on color {
						ColorAnimation { duration: 140 }
					}
				}

				MouseArea {
					id: bellArea

					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: bar.notificationsToggle()
				}
			}

			Rectangle {
				Layout.alignment: Qt.AlignVCenter
				visible: bar.hasPlayer
				width: 1
				height: 15
				color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16)
			}

			Item {
				Layout.alignment: Qt.AlignVCenter
				Layout.preferredWidth: bar.mediaWidth
				Layout.preferredHeight: 18
				visible: bar.mediaWidth > 0.5
				clip: true

				RowLayout {
					id: mediaRow

					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					spacing: 8

					Item {
						id: barPlayButton

						Layout.alignment: Qt.AlignVCenter
						Layout.preferredWidth: 16
						Layout.preferredHeight: 16

						property real swipe: 0
						property real swipeDir: 1

						Connections {
							target: bar

							function onPlayingChanged(): void {
								barPlayButton.swipeDir = bar.playing ? 1 : -1
								barPlaySwipe.restart()
							}
						}

						SequentialAnimation {
							id: barPlaySwipe

							NumberAnimation {
								target: barPlayButton
								property: "swipe"
								to: barPlayButton.swipeDir * 9
								duration: 165
								easing.type: Easing.OutBack
							}
							PropertyAction {
								target: barPlayButton
								property: "swipe"
								value: -barPlayButton.swipeDir * 9
							}
							NumberAnimation {
								target: barPlayButton
								property: "swipe"
								to: 0
								duration: 280
								easing.type: Easing.OutBack
							}
							onFinished: barPlayButton.swipe = 0
						}

						Image {
							anchors.centerIn: parent
							anchors.horizontalCenterOffset: barPlayButton.swipe
							width: 16
							height: 16
							opacity: 1 - Math.min(1, Math.abs(barPlayButton.swipe) / 9)
							source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/moxi/assets/symbols/" + (bar.playing ? "pause-fg.svg" : "play-fg.svg")
							sourceSize.width: 26
							sourceSize.height: 26
							fillMode: Image.PreserveAspectFit
							asynchronous: true
							layer.enabled: true
							layer.effect: MultiEffect {
								colorization: 1
								colorizationColor: bar.accent
								autoPaddingEnabled: false
							}
						}
					}

					Text {
						Layout.alignment: Qt.AlignVCenter
						Layout.preferredWidth: Math.min(implicitWidth, bar.titleWidth)
						color: bar.foreground
						elide: Text.ElideRight
						font.family: bar.songFont(bar.track)
						font.pixelSize: 13
						font.weight: bar.songWeight(bar.track)
						text: bar.track
						wrapMode: Text.NoWrap
					}

					Text {
						Layout.alignment: Qt.AlignVCenter
						Layout.preferredWidth: Math.min(implicitWidth, 150)
						visible: bar.artist.length > 0
						elide: Text.ElideRight
						color: bar.muted
						font.family: bar.songFont(bar.artist)
						font.pixelSize: 13
						font.weight: bar.songWeight(bar.artist)
						text: bar.artist
						wrapMode: Text.NoWrap
					}
				}
			}

			Item {
				id: volumeWrapper

				Layout.alignment: Qt.AlignVCenter
				Layout.preferredWidth: bar.volumeWidth
				Layout.preferredHeight: 18
				visible: bar.volumeWidth > 0.5
				clip: true

				RowLayout {
					id: volumeRow

					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					spacing: 7

					Item {
						Layout.alignment: Qt.AlignVCenter
						Layout.preferredWidth: 46
						Layout.preferredHeight: 5

						Rectangle {
							anchors.fill: parent
							radius: 2.5
							color: bar.idle
						}

						Rectangle {
							anchors.left: parent.left
							anchors.verticalCenter: parent.verticalCenter
							width: bar.sinkMuted ? 0 : Math.max(4, parent.width * bar.sinkVolume)
							height: parent.height
							radius: 2.5
							color: bar.accent
						}
					}

					Text {
						Layout.alignment: Qt.AlignVCenter
						color: bar.foreground
						font.family: bar.fontFamily
						font.pixelSize: 13
						text: bar.sinkMuted ? "muted" : Math.round(bar.sinkVolume * 100) + "%"
					}
				}
			}

			Item {
				Layout.alignment: Qt.AlignVCenter
				Layout.preferredWidth: bar.dateWidth
				Layout.preferredHeight: 18
				visible: bar.dateWidth > 0.5
				clip: true

				Text {
					id: dateLabel

					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					color: bar.muted
					font.family: bar.fontFamily
					font.pixelSize: 13
					text: Qt.formatDateTime(clock.date, "ddd d MMM")
				}
			}
		}
	}
}
