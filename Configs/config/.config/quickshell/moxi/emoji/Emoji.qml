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
	property string query: ""
	property var results: []
	property int selected: 0

	readonly property color accent: theme.accent
	readonly property color foreground: theme.foreground
	readonly property color muted: theme.muted
	readonly property string fontFamily: momo.status === FontLoader.Ready ? momo.name : ""
	readonly property real cornerRadius: emoji.open ? 30 : 19

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

	margins.top: 56
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
		focusTimer.restart()
	}

	function hide(): void {
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

	Item {
		id: cardHost

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		y: emoji.open ? 0 : -30
		width: emoji.open ? 560 : 210
		height: emoji.open ? 440 : 38
		opacity: emoji.open ? 1 : 0
		scale: emoji.open ? 1 : 0.96

		Behavior on width {
			NumberAnimation {
				duration: emoji.open ? 300 : 200
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.2, 0.9, 0.25, 1]
			}
		}

		Behavior on height {
			NumberAnimation {
				duration: emoji.open ? 300 : 200
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.2, 0.9, 0.25, 1]
			}
		}

		Behavior on opacity {
			NumberAnimation { duration: emoji.open ? 200 : 150 }
		}

		Behavior on scale {
			NumberAnimation { duration: emoji.open ? 260 : 180 }
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
