import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../components"

PanelWindow {
	id: emoji

	Theme {
		id: theme
	}

	property bool open: false
	property real anchorWidth: 210
	property real anchorHeight: 38
	property real anchorTop: 4
	readonly property real surfaceTop: 6
	property string query: ""
	property var results: []
	property int selected: 0
	property real contentBlur: 0

	function setAnchor(width: real, height: real, y: real): void {
		emoji.anchorWidth = width
		emoji.anchorHeight = height
		emoji.anchorTop = y
	}

	readonly property color accent: theme.accent
	readonly property color foreground: theme.foreground
	readonly property color muted: theme.muted
	readonly property string fontFamily: momo.status === FontLoader.Ready ? momo.name : ""
	readonly property real cornerRadius: emoji.open ? 30 : emoji.anchorHeight / 2

	property var catalog: []

	FileView {
		id: catalogFile

		path: Quickshell.shellDir + "/emoji/data.json"
		blockLoading: true
		watchChanges: false
	}

	function loadCatalog(): void {
		var raw = catalogFile.text()

		if (!raw || raw.length === 0) return

		try {
			emoji.catalog = JSON.parse(raw)
		} catch (error) {
			emoji.catalog = []
		}
	}

	Component.onCompleted: {
		emoji.loadCatalog()
		emoji.refresh()
	}

	FontLoader {
		id: momo
		source: "../fonts/momotrust.ttf"

		onStatusChanged: if (status === FontLoader.Ready) emoji.fontFamily = name
	}

	anchors {
		top: true
		left: true
		right: true
	}

	margins.top: emoji.surfaceTop
	implicitHeight: 620
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: emoji.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	focusable: true
	color: "transparent"
	mask: Region { item: inputArea }

	function refresh(): void {
		var needle = emoji.query.trim().toLowerCase()
		var found = []

		for (var i = 0; i < emoji.catalog.length; ++i) {
			var entry = emoji.catalog[i]

			if (needle.length === 0 || entry[1].indexOf(needle) !== -1) found.push(entry)
		}

		emoji.results = found
		emoji.selected = 0
	}

	function show(): void {
		emoji.open = true
		emoji.query = ""
		emoji.refresh()
		emoji.contentBlur = 1
		openBlur.restart()
		focusTimer.restart()
	}

	function hide(): void {
		openBlur.stop()
		emoji.contentBlur = 0
		emoji.open = false
	}

	function toggle(): void {
		if (emoji.open) emoji.hide()
		else emoji.show()
	}

	function copy(char): void {
		if (!char) return

		copier.text = char
		copier.running = true
		emoji.hide()
	}

	IpcHandler {
		target: "emoji"

		function toggle(): void {
			emoji.toggle()
		}

		function show(): void {
			emoji.show()
		}

		function hide(): void {
			emoji.hide()
		}
	}

	Process {
		id: copier

		property string text: ""

		command: ["bash", "-c", "printf '%s' \"$1\" | wl-copy", "emoji", copier.text]
	}

	Timer {
		id: focusTimer
		interval: 70
		onTriggered: input.forceActiveFocus()
	}

	SequentialAnimation {
		id: openBlur

		PauseAnimation { duration: 190 }

		NumberAnimation {
			target: emoji
			property: "contentBlur"
			from: 1
			to: 0
			duration: 170
			easing.type: Easing.OutCubic
		}
	}

	Item {
		id: cardHost

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		y: emoji.open ? 50 : emoji.anchorTop
		width: emoji.open ? 560 : emoji.anchorWidth
		height: emoji.open ? 440 : emoji.anchorHeight
		opacity: emoji.open ? 1 : 0
		scale: emoji.open ? 1 : 0.94
		transformOrigin: Item.Center

		Behavior on width {
			NumberAnimation {
				duration: emoji.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on height {
			NumberAnimation {
				duration: emoji.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on y {
			NumberAnimation {
				duration: emoji.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on scale {
			NumberAnimation {
				duration: emoji.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on opacity {
			NumberAnimation { duration: emoji.open ? 220 : 160 }
		}

		Item {
			id: cardSource

			visible: true
			width: cardHost.width
			height: cardHost.height

			Squircle {
				anchors.fill: parent
				power: 4
				radius: emoji.cornerRadius
				fillColor: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.74)
				strokeColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.26)
				strokeWidth: 1
			}

			Item {
				anchors.fill: parent
				anchors.margins: 20
				layer.enabled: emoji.contentBlur > 0.004

				layer.effect: MultiEffect {
					blurEnabled: true
					blurMax: 34
					blur: emoji.contentBlur
				}

				Rectangle {
					id: searchFrame

					anchors.top: parent.top
					anchors.left: parent.left
					anchors.right: parent.right
					height: 42
					radius: 21
					color: Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.35)

					Text {
						anchors.left: parent.left
						anchors.leftMargin: 16
						anchors.verticalCenter: parent.verticalCenter
						color: emoji.muted
						font.family: emoji.fontFamily
						font.pixelSize: 14
						text: "Search emoji"
						visible: input.text.length === 0
					}

					TextInput {
						id: input

						anchors.fill: parent
						anchors.leftMargin: 16
						anchors.rightMargin: 16
						verticalAlignment: TextInput.AlignVCenter
						color: emoji.foreground
						font.family: emoji.fontFamily
						font.pixelSize: 14
						selectionColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.4)
						selectedTextColor: emoji.foreground
						clip: true
						focus: emoji.open

						onTextChanged: {
							emoji.query = text
							emoji.refresh()
						}

						Keys.onEscapePressed: emoji.hide()
						Keys.onReturnPressed: emoji.copy(emoji.results.length > 0 ? emoji.results[0][0] : "")
					}
				}

				GridView {
					id: grid

					anchors.top: searchFrame.bottom
					anchors.topMargin: 14
					anchors.left: parent.left
					anchors.right: parent.right
					anchors.bottom: parent.bottom
					clip: true
					cacheBuffer: 600
					cellWidth: 52
					cellHeight: 52
					model: emoji.results

					delegate: Rectangle {
						id: cell

						required property var modelData
						required property int index

						width: grid.cellWidth - 6
						height: grid.cellHeight - 6
						radius: 14
						color: cellMouse.containsMouse
							? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.24)
							: "transparent"
						scale: cellMouse.containsMouse ? 1.08 : 1

						Behavior on color {
							ColorAnimation { duration: 120 }
						}

						Behavior on scale {
							NumberAnimation { duration: 130 }
						}

						Text {
							anchors.centerIn: parent
							font.pixelSize: 26
							text: cell.modelData[0]
						}

						MouseArea {
							id: cellMouse

							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: emoji.copy(cell.modelData[0])
						}
					}
				}

				Text {
					anchors.centerIn: parent
					visible: emoji.results.length === 0
					color: emoji.muted
					font.family: emoji.fontFamily
					font.pixelSize: 13
					text: "no emoji found"
				}
			}
		}
	}

	Item {
		id: inputArea

		anchors.horizontalCenter: cardHost.horizontalCenter
		anchors.top: cardHost.top
		width: emoji.open ? cardHost.width : 0
		height: emoji.open ? cardHost.height : 0
	}
}
