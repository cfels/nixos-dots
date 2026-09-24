import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../components"

PanelWindow {
	id: clipboard

	Theme {
		id: theme
	}

	property bool open: false
	property var entries: []
	property int selected: 0
	property int previewVersion: 0
	property var readyIds: []
	property var stagedEntries: []
	property string pendingSelection: ""
	property string previewDir: Quickshell.env("HOME") + "/.cache/moxi-clip"

	function hasPreview(entry): bool {
		return entry && entry.binary && clipboard.readyIds.indexOf(entry.id) !== -1
	}

	function isBinary(preview): bool {
		return preview.indexOf("[[ binary data") === 0
	}

	readonly property color accent: theme.accent
	readonly property color foreground: theme.foreground
	readonly property color muted: theme.muted
	readonly property string fontFamily: momo.status === FontLoader.Ready ? momo.name : ""
	readonly property real cornerRadius: clipboard.open ? 30 : 19

	FontLoader {
		id: momo
		source: "../fonts/momotrust.ttf"
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
	WlrLayershell.keyboardFocus: clipboard.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	focusable: true
	color: "transparent"
	mask: Region { item: inputArea }

	function refresh(keepSelection): void {
		var previous = clipboard.entries.length > clipboard.selected && clipboard.selected >= 0
			? clipboard.entries[clipboard.selected].id
			: ""

		clipboard.stagedEntries = []
		clipboard.readyIds = []
		lister.binaryIds = []
		clipboard.pendingSelection = keepSelection === true ? previous : ""
		lister.running = true
	}

	function show(): void {
		clipboard.open = true
		clipboard.refresh()
		focusTimer.restart()
	}

	function hide(): void {
		clipboard.open = false
	}

	function toggle(): void {
		if (clipboard.open) clipboard.hide()
		else clipboard.show()
	}

	function copy(id): void {
		if (id === undefined || id === null || id === "") return

		copier.entryId = String(id)
		copier.running = true
		clipboard.hide()
	}

	IpcHandler {
		target: "clipboard"

		function toggle(): void {
			clipboard.toggle()
		}

		function show(): void {
			clipboard.show()
		}

		function hide(): void {
			clipboard.hide()
		}

		function clear(): void {
			clearer.running = true
		}
	}

	Process {
		id: lister

		property var binaryIds: []

		command: ["bash", "-c", "cliphist list 2>/dev/null | head -200"]

		stdout: SplitParser {
			onRead: (line) => {
				var separator = line.indexOf("\t")

				if (separator <= 0) return

				var id = line.substring(0, separator)
				var preview = line.substring(separator + 1)
				var binary = clipboard.isBinary(preview)

				clipboard.stagedEntries = clipboard.stagedEntries.concat([{
					id: id,
					preview: preview,
					binary: binary
				}])

				if (binary) lister.binaryIds = lister.binaryIds.concat([id])
			}
		}
	}

	Process {
		id: previewDump

		command: [
			"bash",
			"-c",
			"dir=\"$1\"; mkdir -p \"$dir\"; shift; for id in \"$@\"; do if [ -s \"$dir/$id.png\" ] || cliphist decode \"$id\" > \"$dir/$id.png\" 2>/dev/null; then [ -s \"$dir/$id.png\" ] && printf '%s\\n' \"$id\"; else rm -f \"$dir/$id.png\"; fi; done",
			"clipboard-previews",
			clipboard.previewDir,
			lister.binaryIds
		]

		stdout: SplitParser {
			onRead: (line) => {
				if (line.length > 0) clipboard.readyIds = clipboard.readyIds.concat([line])
			}
		}

		onExited: (code, status) => clipboard.previewVersion++
	}

	Process {
		id: copier

		property string entryId: ""

		command: ["bash", "-c", "cliphist decode \"$1\" | wl-copy", "clipboard", copier.entryId]
	}

	Process {
		id: clearer

		command: ["bash", "-c", "cliphist wipe && wl-copy --clear"]

		onExited: (code, status) => clipboard.refresh()
	}

	Connections {
		target: lister

		function onRunningChanged() {
			if (lister.running) return

			var staged = clipboard.stagedEntries
			var changed = staged.length !== clipboard.entries.length

			if (!changed) {
				for (var i = 0; i < staged.length; ++i) {
					if (staged[i].id !== clipboard.entries[i].id
						|| staged[i].preview !== clipboard.entries[i].preview) {
						changed = true
						break
					}
				}
			}

			if (changed) clipboard.entries = staged

			if (clipboard.pendingSelection.length > 0) {
				for (var j = 0; j < clipboard.entries.length; ++j) {
					if (clipboard.entries[j].id === clipboard.pendingSelection) {
						clipboard.selected = j
						break
					}
				}

				clipboard.pendingSelection = ""
			}

			if (lister.binaryIds.length > 0) previewDump.running = true
		}
	}

	Timer {
		id: liveRefresh

		interval: 1000
		running: clipboard.open
		repeat: true

		onTriggered: clipboard.refresh(true)
	}

	Timer {
		id: focusTimer
		interval: 80
		onTriggered: keys.forceActiveFocus()
	}

	Item {
		id: keys

		anchors.fill: parent
		focus: clipboard.open

		Keys.onDownPressed: clipboard.selected = Math.min(clipboard.selected + 1, clipboard.entries.length - 1)
		Keys.onUpPressed: clipboard.selected = Math.max(clipboard.selected - 1, 0)
		Keys.onReturnPressed: clipboard.copy(clipboard.entries[clipboard.selected] ? clipboard.entries[clipboard.selected].id : "")
		Keys.onEnterPressed: clipboard.copy(clipboard.entries[clipboard.selected] ? clipboard.entries[clipboard.selected].id : "")
		Keys.onEscapePressed: clipboard.hide()
	}

	Item {
		id: cardHost

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		y: clipboard.open ? 0 : -30
		width: clipboard.open ? 640 : 210
		height: clipboard.open ? 460 : 38
		opacity: clipboard.open ? 1 : 0

		Behavior on width {
			NumberAnimation {
				duration: clipboard.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on height {
			NumberAnimation {
				duration: clipboard.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on y {
			NumberAnimation {
				duration: clipboard.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		scale: clipboard.open ? 1 : 0.94
		transformOrigin: Item.Center

		Behavior on scale {
			NumberAnimation {
				duration: clipboard.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on opacity {
			NumberAnimation { duration: clipboard.open ? 220 : 160 }
		}

		Item {
			id: cardSource

			visible: true
			width: cardHost.width
			height: cardHost.height

			Squircle {
				anchors.fill: parent
				power: 4
				radius: clipboard.cornerRadius
				fillColor: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.74)
				strokeColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.26)
				strokeWidth: 1
			}

			Item {
				anchors.fill: parent
				anchors.margins: 22

				Text {
					id: title

					anchors.left: parent.left
					anchors.verticalCenter: headerRow.verticalCenter
					color: clipboard.foreground
					font.family: clipboard.fontFamily
					font.pixelSize: 16
					font.weight: Font.DemiBold
					text: "Clipboard"
				}

				Item {
					id: headerRow

					anchors.top: parent.top
					anchors.left: parent.left
					anchors.right: parent.right
					height: 34
				}

				Rectangle {
					id: clearButton

					anchors.right: parent.right
					anchors.verticalCenter: headerRow.verticalCenter
					width: clearLabel.implicitWidth + 26
					height: 30
					radius: 15
					color: clearMouse.containsMouse
						? Qt.rgba(theme.danger.r, theme.danger.g, theme.danger.b, 0.3)
						: Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.35)

					Behavior on color {
						ColorAnimation { duration: 130 }
					}

					Text {
						id: clearLabel

						anchors.centerIn: parent
						color: theme.danger
						font.family: clipboard.fontFamily
						font.pixelSize: 12
						text: "Clear all"
					}

					MouseArea {
						id: clearMouse

						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: clearer.running = true
					}
				}

				ListView {
					id: list

					anchors.top: headerRow.bottom
					anchors.topMargin: 12
					anchors.left: parent.left
					anchors.right: parent.right
					anchors.bottom: parent.bottom
					clip: true
					spacing: 4
					model: clipboard.entries
					currentIndex: clipboard.selected

					delegate: Rectangle {
						id: row

						required property var modelData
						required property int index

						width: list.width
						height: 42
						radius: 13
						color: index === clipboard.selected
							? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.22)
							: (rowMouse.containsMouse ? Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.35) : "transparent")

						Behavior on color {
							ColorAnimation { duration: 120 }
						}

						Text {
							anchors.left: parent.left
							anchors.leftMargin: 14
							anchors.right: parent.right
							anchors.rightMargin: 14
							anchors.verticalCenter: parent.verticalCenter
							color: clipboard.foreground
							elide: Text.ElideRight
							font.family: clipboard.fontFamily
							font.pixelSize: 13
							text: row.modelData.preview
							visible: !(row.modelData.binary && thumb.status === Image.Ready)
							wrapMode: Text.NoWrap
						}

						SquircleImage {
							id: thumb

							anchors.left: parent.left
							anchors.leftMargin: 8
							anchors.verticalCenter: parent.verticalCenter
							width: 46
							height: 34
							radius: 9
							power: 4
							visible: row.modelData.binary && thumb.status === Image.Ready
							source: row.modelData.binary
								? "file://" + clipboard.previewDir + "/" + row.modelData.id + ".png?v=" + clipboard.previewVersion
								: ""
						}

						MouseArea {
							id: rowMouse

							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onEntered: clipboard.selected = row.index
							onClicked: clipboard.copy(row.modelData.id)
						}
					}
				}

				Text {
					anchors.centerIn: parent
					visible: clipboard.entries.length === 0
					color: clipboard.muted
					font.family: clipboard.fontFamily
					font.pixelSize: 13
					text: "Clipboard history is empty"
				}
			}
		}

	}

	Item {
		id: inputArea

		anchors.horizontalCenter: cardHost.horizontalCenter
		anchors.top: cardHost.top
		width: clipboard.open ? cardHost.width : 0
		height: clipboard.open ? cardHost.height : 0
	}
}
