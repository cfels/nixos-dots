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
	property var surfaceHost: null
	visible: surfaceHost === null
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
	WlrLayershell.keyboardFocus: !emoji.surfaceHost && emoji.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

	function move(delta): void {
		if (emoji.results.length === 0) return

		grid.followSelection = true
		emoji.selected = Math.max(0, Math.min(emoji.selected + delta, emoji.results.length - 1))
	}

	function show(): void {
		input.clear()
		emoji.query = ""
		emoji.refresh()
		emoji.open = true
		if (!emoji.surfaceHost) {
			emoji.contentBlur = 1
			openBlur.restart()
		}
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
		onTriggered: if (emoji.open) input.forceActiveFocus()
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

			parent: emoji.surfaceHost || cardHost
			visible: true
			width: parent.width
			height: parent.height

			Squircle {
				visible: !emoji.surfaceHost
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
						Keys.onDownPressed: emoji.move(Math.max(1, Math.floor(grid.width / grid.cellWidth)))
						Keys.onUpPressed: emoji.move(-Math.max(1, Math.floor(grid.width / grid.cellWidth)))
						Keys.onReturnPressed: emoji.copy(emoji.results[emoji.selected] ? emoji.results[emoji.selected][0] : "")
						Keys.onEnterPressed: emoji.copy(emoji.results[emoji.selected] ? emoji.results[emoji.selected][0] : "")

						Keys.onPressed: function(event) {
							if (input.text.length === 0 && event.key === Qt.Key_Left) {
								emoji.move(-1)
								event.accepted = true
							} else if (input.text.length === 0 && event.key === Qt.Key_Right) {
								emoji.move(1)
								event.accepted = true
							}
						}
					}
				}

				GridView {
					id: grid
					property bool followSelection: true

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
					currentIndex: emoji.selected
					highlightFollowsCurrentItem: true
					highlightMoveDuration: followSelection ? 0 : 270
					highlightRangeMode: followSelection ? GridView.ApplyRange : GridView.NoHighlightRange
					preferredHighlightBegin: Math.max(0, (height - cellHeight) / 2)
					preferredHighlightEnd: preferredHighlightBegin + cellHeight

					onCountChanged: positionViewAtBeginning()

					MouseArea {
						parent: grid
						anchors.fill: parent
						acceptedButtons: Qt.NoButton
						hoverEnabled: true
						onPositionChanged: function(mouse) {
							if (grid.moving) return

							var index = grid.indexAt(mouse.x + grid.contentX, mouse.y + grid.contentY)
							if (index < 0) return

							grid.followSelection = false
							emoji.selected = index
						}
					}

					WheelHandler {
						target: null
						blocking: false
						onWheel: (event) => {
							grid.followSelection = false
							event.accepted = false
						}
					}

					highlight: Rectangle {
						width: grid.cellWidth - 6
						height: grid.cellHeight - 6
						radius: 14
						color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.24)
						visible: grid.currentItem !== null
					}

					delegate: Item {
						id: cell

						required property var modelData
						required property int index

						width: grid.cellWidth - 6
						height: grid.cellHeight - 6
						scale: index === emoji.selected ? 1.08 : 1

						Behavior on scale {
							SmoothedAnimation { duration: 250; velocity: -1 }
						}

						Text {
							anchors.centerIn: parent
							font.pixelSize: 26
							text: cell.modelData[0]
						}

						MouseArea {
							id: cellMouse

							anchors.fill: parent
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
